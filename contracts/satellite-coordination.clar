;; Satellite Coordination Contract
;; Manages space infrastructure and satellite coordination

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_SATELLITE_EXISTS (err u201))
(define-constant ERR_SATELLITE_NOT_FOUND (err u202))
(define-constant ERR_INVALID_ORBIT (err u203))
(define-constant ERR_COLLISION_RISK (err u204))

;; Orbit types
(define-constant ORBIT_LEO u1) ;; Low Earth Orbit
(define-constant ORBIT_MEO u2) ;; Medium Earth Orbit
(define-constant ORBIT_GEO u3) ;; Geostationary Orbit

;; Satellite data structure
(define-map satellites
  { satellite-id: uint }
  {
    owner: principal,
    name: (string-ascii 64),
    orbit-type: uint,
    altitude: uint,
    longitude: int,
    latitude: int,
    status: (string-ascii 16),
    launch-date: uint,
    mission-duration: uint
  }
)

(define-map orbital-slots
  { orbit-type: uint, slot-id: uint }
  { occupied: bool, satellite-id: uint }
)

(define-data-var next-satellite-id uint u1)
(define-data-var next-slot-id uint u1)

;; Register a new satellite
(define-public (register-satellite
  (name (string-ascii 64))
  (orbit-type uint)
  (altitude uint)
  (longitude int)
  (latitude int)
  (mission-duration uint)
)
  (let ((satellite-id (var-get next-satellite-id)))
    (asserts! (is-none (map-get? satellites { satellite-id: satellite-id })) ERR_SATELLITE_EXISTS)
    (asserts! (or (is-eq orbit-type ORBIT_LEO) (is-eq orbit-type ORBIT_MEO) (is-eq orbit-type ORBIT_GEO)) ERR_INVALID_ORBIT)

    ;; Check for collision risk (simplified)
    (asserts! (not (has-collision-risk orbit-type altitude longitude latitude)) ERR_COLLISION_RISK)

    (map-set satellites
      { satellite-id: satellite-id }
      {
        owner: tx-sender,
        name: name,
        orbit-type: orbit-type,
        altitude: altitude,
        longitude: longitude,
        latitude: latitude,
        status: "registered",
        launch-date: u0,
        mission-duration: mission-duration
      }
    )
    (var-set next-satellite-id (+ satellite-id u1))
    (ok satellite-id)
  )
)

;; Update satellite status
(define-public (update-satellite-status (satellite-id uint) (new-status (string-ascii 16)))
  (match (map-get? satellites { satellite-id: satellite-id })
    satellite-data
    (begin
      (asserts! (is-eq tx-sender (get owner satellite-data)) ERR_UNAUTHORIZED)
      (map-set satellites
        { satellite-id: satellite-id }
        (merge satellite-data { status: new-status })
      )
      (ok true)
    )
    ERR_SATELLITE_NOT_FOUND
  )
)

;; Reserve orbital slot
(define-public (reserve-orbital-slot (orbit-type uint) (satellite-id uint))
  (let ((slot-id (var-get next-slot-id)))
    (asserts! (is-some (map-get? satellites { satellite-id: satellite-id })) ERR_SATELLITE_NOT_FOUND)
    (map-set orbital-slots
      { orbit-type: orbit-type, slot-id: slot-id }
      { occupied: true, satellite-id: satellite-id }
    )
    (var-set next-slot-id (+ slot-id u1))
    (ok slot-id)
  )
)

;; Simplified collision detection
(define-private (has-collision-risk (orbit-type uint) (altitude uint) (longitude int) (latitude int))
  ;; Simplified logic - in reality this would be much more complex
  (if (< altitude u200) ;; Too low altitude
    true
    false
  )
)

;; Get satellite information
(define-read-only (get-satellite (satellite-id uint))
  (map-get? satellites { satellite-id: satellite-id })
)

;; Get orbital slot information
(define-read-only (get-orbital-slot (orbit-type uint) (slot-id uint))
  (map-get? orbital-slots { orbit-type: orbit-type, slot-id: slot-id })
)
