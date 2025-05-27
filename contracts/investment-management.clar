;; Investment Management Contract
;; Manages space infrastructure funding and investments

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INSUFFICIENT_FUNDS (err u501))
(define-constant ERR_INVESTMENT_NOT_FOUND (err u502))
(define-constant ERR_INVALID_AMOUNT (err u503))
(define-constant ERR_PROJECT_NOT_FOUND (err u504))

;; Investment project data structure
(define-map investment-projects
  { project-id: uint }
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    target-amount: uint,
    raised-amount: uint,
    project-owner: principal,
    start-date: uint,
    end-date: uint,
    status: (string-ascii 16)
  }
)

;; Individual investments
(define-map investments
  { investment-id: uint }
  {
    investor: principal,
    project-id: uint,
    amount: uint,
    investment-date: uint,
    returns-claimed: uint
  }
)

;; Investment returns tracking
(define-map project-returns
  { project-id: uint }
  {
    total-returns: uint,
    returns-per-token: uint,
    distribution-date: uint
  }
)

(define-data-var next-project-id uint u1)
(define-data-var next-investment-id uint u1)
(define-data-var total-platform-funds uint u0)

;; Create investment project
(define-public (create-project
  (name (string-ascii 64))
  (description (string-ascii 256))
  (target-amount uint)
  (duration uint)
)
  (let ((project-id (var-get next-project-id)))
    (asserts! (> target-amount u0) ERR_INVALID_AMOUNT)
    (map-set investment-projects
      { project-id: project-id }
      {
        name: name,
        description: description,
        target-amount: target-amount,
        raised-amount: u0,
        project-owner: tx-sender,
        start-date: block-height,
        end-date: (+ block-height duration),
        status: "active"
      }
    )
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

;; Make investment in project
(define-public (invest-in-project (project-id uint) (amount uint))
  (let ((investment-id (var-get next-investment-id)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (match (map-get? investment-projects { project-id: project-id })
      project-data
      (begin
        ;; In a real implementation, we'd handle STX transfers here
        (map-set investments
          { investment-id: investment-id }
          {
            investor: tx-sender,
            project-id: project-id,
            amount: amount,
            investment-date: block-height,
            returns-claimed: u0
          }
        )
        ;; Update project raised amount
        (map-set investment-projects
          { project-id: project-id }
          (merge project-data {
            raised-amount: (+ (get raised-amount project-data) amount)
          })
        )
        (var-set next-investment-id (+ investment-id u1))
        (var-set total-platform-funds (+ (var-get total-platform-funds) amount))
        (ok investment-id)
      )
      ERR_PROJECT_NOT_FOUND
    )
  )
)

;; Distribute returns to investors
(define-public (distribute-returns (project-id uint) (total-returns uint))
  (match (map-get? investment-projects { project-id: project-id })
    project-data
    (begin
      (asserts! (is-eq tx-sender (get project-owner project-data)) ERR_UNAUTHORIZED)
      (asserts! (> total-returns u0) ERR_INVALID_AMOUNT)
      (let ((raised-amount (get raised-amount project-data)))
        (if (> raised-amount u0)
          (let ((returns-per-token (/ total-returns raised-amount)))
            (map-set project-returns
              { project-id: project-id }
              {
                total-returns: total-returns,
                returns-per-token: returns-per-token,
                distribution-date: block-height
              }
            )
            (ok returns-per-token)
          )
          ERR_INSUFFICIENT_FUNDS
        )
      )
    )
    ERR_PROJECT_NOT_FOUND
  )
)

;; Claim investment returns
(define-public (claim-returns (investment-id uint))
  (match (map-get? investments { investment-id: investment-id })
    investment-data
    (begin
      (asserts! (is-eq tx-sender (get investor investment-data)) ERR_UNAUTHORIZED)
      (let ((project-id (get project-id investment-data))
            (investment-amount (get amount investment-data)))
        (match (map-get? project-returns { project-id: project-id })
          returns-data
          (let ((returns-amount (* investment-amount (get returns-per-token returns-data))))
            ;; In a real implementation, we'd transfer STX here
            (map-set investments
              { investment-id: investment-id }
              (merge investment-data { returns-claimed: returns-amount })
            )
            (ok returns-amount)
          )
          ERR_INVESTMENT_NOT_FOUND
        )
      )
    )
    ERR_INVESTMENT_NOT_FOUND
  )
)

;; Update project status
(define-public (update-project-status (project-id uint) (new-status (string-ascii 16)))
  (match (map-get? investment-projects { project-id: project-id })
    project-data
    (begin
      (asserts! (is-eq tx-sender (get project-owner project-data)) ERR_UNAUTHORIZED)
      (map-set investment-projects
        { project-id: project-id }
        (merge project-data { status: new-status })
      )
      (ok true)
    )
    ERR_PROJECT_NOT_FOUND
  )
)

;; Get project information
(define-read-only (get-project (project-id uint))
  (map-get? investment-projects { project-id: project-id })
)

;; Get investment information
(define-read-only (get-investment (investment-id uint))
  (map-get? investments { investment-id: investment-id })
)

;; Get project returns information
(define-read-only (get-project-returns (project-id uint))
  (map-get? project-returns { project-id: project-id })
)

;; Get total platform funds
(define-read-only (get-total-platform-funds)
  (var-get total-platform-funds)
)
