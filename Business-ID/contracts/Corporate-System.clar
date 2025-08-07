;; Global LEI Registry - Essential Blockchain Operations
;;
;; A focused blockchain registry for Legal Entity Identifiers (LEI) that balances
;; essential on-chain functionality with gas efficiency. Handles critical operations
;; that require immutability and consensus while keeping costs reasonable.
;;
;; Essential On-Chain Features:
;; - LEI registration with ownership and basic metadata
;; - Multi-status lifecycle management (active, suspended, expired, retired)
;; - Ownership transfers with event logging
;; - Expiration tracking for regulatory compliance
;; - Portfolio tracking for owned LEIs
;; - Role-based administrative controls
;; - Essential validation for data integrity

;; ERROR CONSTANTS

;; Access Control Errors
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-NOT-OWNER (err u101))
(define-constant ERR-NOT-ADMIN (err u102))
(define-constant ERR-INVALID-ADMIN (err u103))

;; Validation Errors
(define-constant ERR-INVALID-LEI-FORMAT (err u200))
(define-constant ERR-INVALID-STATUS (err u201))
(define-constant ERR-INVALID-EXPIRATION (err u202))
(define-constant ERR-INVALID-ADDRESS (err u203))

;; Business Logic Errors
(define-constant ERR-LEI-EXISTS (err u300))
(define-constant ERR-LEI-NOT-FOUND (err u301))
(define-constant ERR-LEI-EXPIRED (err u302))
(define-constant ERR-SAME-OWNER (err u303))

;; CORE DATA STRUCTURES

;; Primary LEI registry with essential on-chain data
(define-map lei-registry
  { lei: (string-ascii 20) }
  {
    owner: principal,
    status: (string-ascii 12), ;; ACTIVE, SUSPENDED, EXPIRED, RETIRED
    registered-at: uint,
    expires-at: uint,
    last-updated: uint
  }
)

;; Owner portfolio tracking (essential for ownership queries)
(define-map owner-portfolios
  { owner: principal }
  { lei-count: uint, leis: (list 50 (string-ascii 20)) }
)

;; Administrative roles
(define-map admins
  { admin: principal }
  { authorized: bool, role: (string-ascii 10) } ;; SUPER, BASIC
)

;; Contract governance
(define-data-var contract-owner principal tx-sender)
(define-data-var total-registrations uint u0)


;; VALIDATION FUNCTIONS


;; Validates LEI format (20 alphanumeric characters)
(define-private (is-valid-lei (lei (string-ascii 20)))
  (is-eq (len lei) u20)
)

;; Validates status codes
(define-private (is-valid-status (status (string-ascii 12)))
  (or (is-eq status "ACTIVE")
      (is-eq status "SUSPENDED") 
      (is-eq status "EXPIRED")
      (is-eq status "RETIRED"))
)

;; Validates principal address (checks if it's a valid standard principal)
(define-private (is-valid-principal (address principal))
  (is-standard address)
)

;; Checks if caller has admin privileges
(define-private (is-admin)
  (let ((admin-record (map-get? admins { admin: tx-sender })))
    (or
      (is-eq tx-sender (var-get contract-owner))
      (and (is-some admin-record) 
           (get authorized (unwrap-panic admin-record)))
    )
  )
)

;; Checks if caller is super admin
(define-private (is-super-admin)
  (let ((admin-record (map-get? admins { admin: tx-sender })))
    (or
      (is-eq tx-sender (var-get contract-owner))
      (and (is-some admin-record)
           (get authorized (unwrap-panic admin-record))
           (is-eq (get role (unwrap-panic admin-record)) "SUPER"))
    )
  )
)

;; Checks if caller can modify specific LEI
(define-private (can-modify-lei (lei (string-ascii 20)))
  (let ((lei-record (map-get? lei-registry { lei: lei })))
    (if (is-some lei-record)
      (let ((lei-data (unwrap-panic lei-record)))
        (or (is-admin) (is-eq tx-sender (get owner lei-data)))
      )
      false
    )
  )
)

;; PORTFOLIO MANAGEMENT

;; Add LEI to owner's portfolio
(define-private (add-to-portfolio (lei (string-ascii 20)) (owner principal))
  (let ((portfolio (default-to 
                     { lei-count: u0, leis: (list) }
                     (map-get? owner-portfolios { owner: owner }))))
    (let ((current-leis (get leis portfolio))
          (current-count (get lei-count portfolio)))
      (match (as-max-len? (append current-leis lei) u50)
        updated-leis (begin
          (map-set owner-portfolios
            { owner: owner }
            { lei-count: (+ current-count u1), leis: updated-leis })
          true)
        false)
    )
  )
)

;; Remove LEI from owner's portfolio
(define-private (remove-from-portfolio (lei (string-ascii 20)) (owner principal))
  (let ((portfolio (map-get? owner-portfolios { owner: owner })))
    (if (is-some portfolio)
      (let ((portfolio-data (unwrap-panic portfolio))
            (current-leis (get leis portfolio-data))
            (current-count (get lei-count portfolio-data)))
        (let ((filtered-result (fold filter-lei-from-list current-leis 
                                 { target-lei: lei, result: (list) })))
          (map-set owner-portfolios
            { owner: owner }
            { lei-count: (- current-count u1), leis: (get result filtered-result) })
          true
        ))
      true
    )
  )
)

;; Helper function to filter out target LEI from list
(define-private (filter-lei-from-list 
  (lei-item (string-ascii 20))
  (acc { target-lei: (string-ascii 20), result: (list 50 (string-ascii 20)) }))
  (let ((target (get target-lei acc))
        (current-result (get result acc)))
    (if (is-eq lei-item target)
      acc
      { 
        target-lei: target,
        result: (default-to current-result (as-max-len? (append current-result lei-item) u50))
      }
    )
  )
)

;; ADMINISTRATIVE FUNCTIONS

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal new-owner) ERR-INVALID-ADDRESS)
    (asserts! (not (is-eq new-owner tx-sender)) ERR-SAME-OWNER)
    (ok (var-set contract-owner new-owner))
  )
)

;; Add admin with role
(define-public (add-admin (admin-address principal) (admin-role (string-ascii 10)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal admin-address) ERR-INVALID-ADDRESS)
    (asserts! (or (is-eq admin-role "SUPER") (is-eq admin-role "BASIC")) ERR-INVALID-ADMIN)
    (asserts! (not (is-eq admin-address tx-sender)) ERR-SAME-OWNER)
    (ok (map-set admins 
      { admin: admin-address } 
      { authorized: true, role: admin-role }))
  )
)

;; Remove admin
(define-public (remove-admin (admin-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal admin-address) ERR-INVALID-ADDRESS)
    (asserts! (not (is-eq admin-address tx-sender)) ERR-SAME-OWNER)
    (ok (map-set admins 
      { admin: admin-address } 
      { authorized: false, role: "NONE" }))
  )
)

;; CORE LEI MANAGEMENT FUNCTIONS

;; Register new LEI with essential data
(define-public (register-lei 
  (lei (string-ascii 20)) 
  (lei-owner principal) 
  (expiration-height uint))
  (begin
    (asserts! (is-admin) ERR-NOT-ADMIN)
    (asserts! (is-valid-lei lei) ERR-INVALID-LEI-FORMAT)
    (asserts! (is-valid-principal lei-owner) ERR-INVALID-ADDRESS)
    (asserts! (> expiration-height block-height) ERR-INVALID-EXPIRATION)
    (asserts! (is-none (map-get? lei-registry { lei: lei })) ERR-LEI-EXISTS)
    
    ;; Create LEI record
    (map-set lei-registry
      { lei: lei }
      {
        owner: lei-owner,
        status: "ACTIVE",
        registered-at: block-height,
        expires-at: expiration-height,
        last-updated: block-height
      }
    )
    
    ;; Add to owner's portfolio
    (asserts! (add-to-portfolio lei lei-owner) ERR-INVALID-ADDRESS)
    
    ;; Update total count
    (var-set total-registrations (+ (var-get total-registrations) u1))
    
    ;; Print event for off-chain indexing
    (print {
      event: "lei-registered",
      lei: lei,
      owner: lei-owner,
      block: block-height
    })
    
    (ok true)
  )
)

;; Transfer LEI ownership
(define-public (transfer-lei (lei (string-ascii 20)) (new-owner principal))
  (begin
    (asserts! (is-valid-lei lei) ERR-INVALID-LEI-FORMAT)
    (asserts! (is-valid-principal new-owner) ERR-INVALID-ADDRESS)
    (asserts! (can-modify-lei lei) ERR-NOT-OWNER)
    
    (let ((lei-record (unwrap! (map-get? lei-registry { lei: lei }) ERR-LEI-NOT-FOUND)))
      (let ((current-owner (get owner lei-record)))
        (asserts! (not (is-eq current-owner new-owner)) ERR-SAME-OWNER)
        
        ;; Update ownership
        (map-set lei-registry
          { lei: lei }
          (merge lei-record { 
            owner: new-owner, 
            last-updated: block-height 
          })
        )
        
        ;; Update portfolios
        (asserts! (remove-from-portfolio lei current-owner) ERR-INVALID-ADDRESS)
        (asserts! (add-to-portfolio lei new-owner) ERR-INVALID-ADDRESS)
        
        ;; Print event
        (print {
          event: "lei-transferred",
          lei: lei,
          from: current-owner,
          to: new-owner,
          block: block-height
        })
        
        (ok true)
      )
    )
  )
)

;; Update LEI status
(define-public (update-lei-status (lei (string-ascii 20)) (new-status (string-ascii 12)))
  (begin
    (asserts! (is-admin) ERR-NOT-ADMIN)
    (asserts! (is-valid-lei lei) ERR-INVALID-LEI-FORMAT)
    (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)
    
    (let ((lei-record (unwrap! (map-get? lei-registry { lei: lei }) ERR-LEI-NOT-FOUND)))
      (map-set lei-registry
        { lei: lei }
        (merge lei-record { 
          status: new-status, 
          last-updated: block-height 
        })
      )
      
      ;; Print event
      (print {
        event: "status-updated",
        lei: lei,
        status: new-status,
        block: block-height
      })
      
      (ok true)
    )
  )
)

;; Extend LEI expiration
(define-public (extend-lei-expiration (lei (string-ascii 20)) (new-expiration uint))
  (begin
    (asserts! (is-admin) ERR-NOT-ADMIN)
    (asserts! (is-valid-lei lei) ERR-INVALID-LEI-FORMAT)
    (asserts! (> new-expiration block-height) ERR-INVALID-EXPIRATION)
    
    (let ((lei-record (unwrap! (map-get? lei-registry { lei: lei }) ERR-LEI-NOT-FOUND)))
      (map-set lei-registry
        { lei: lei }
        (merge lei-record { 
          expires-at: new-expiration,
          status: "ACTIVE",
          last-updated: block-height 
        })
      )
      
      (print {
        event: "expiration-extended",
        lei: lei,
        expires-at: new-expiration,
        block: block-height
      })
      
      (ok true)
    )
  )
)

;; Batch update expired LEIs (super admin only)
(define-public (batch-expire-leis (lei-list (list 20 (string-ascii 20))))
  (begin
    (asserts! (is-super-admin) ERR-UNAUTHORIZED-ACCESS)
    (ok (map expire-lei-if-needed lei-list))
  )
)

;; Helper function to expire LEI if needed
(define-private (expire-lei-if-needed (lei (string-ascii 20)))
  (let ((lei-record (map-get? lei-registry { lei: lei })))
    (if (is-some lei-record)
      (let ((lei-data (unwrap-panic lei-record)))
        (if (and (< (get expires-at lei-data) block-height)
                 (is-eq (get status lei-data) "ACTIVE"))
          (map-set lei-registry
            { lei: lei }
            (merge lei-data { 
              status: "EXPIRED", 
              last-updated: block-height 
            }))
          false))
      false)
  )
)

;; READ-ONLY FUNCTIONS

;; Get complete LEI details
(define-read-only (get-lei-details (lei (string-ascii 20)))
  (ok (map-get? lei-registry { lei: lei }))
)

;; Check if LEI is active and valid
(define-read-only (is-lei-valid (lei (string-ascii 20)))
  (let ((lei-record (map-get? lei-registry { lei: lei })))
    (if (is-some lei-record)
      (let ((lei-data (unwrap-panic lei-record)))
        (ok (and (is-eq (get status lei-data) "ACTIVE")
                 (> (get expires-at lei-data) block-height))))
      ERR-LEI-NOT-FOUND
    )
  )
)

;; Get owner's portfolio
(define-read-only (get-owner-portfolio (owner principal))
  (ok (default-to 
        { lei-count: u0, leis: (list) }
        (map-get? owner-portfolios { owner: owner })))
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  (ok {
    total-registrations: (var-get total-registrations),
    contract-owner: (var-get contract-owner),
    current-block: block-height
  })
)

;; Check admin status and role
(define-read-only (get-admin-info (address principal))
  (let ((admin-record (map-get? admins { admin: address })))
    (ok {
      is-owner: (is-eq address (var-get contract-owner)),
      is-admin: (and (is-some admin-record) 
                     (get authorized (unwrap-panic admin-record))),
      role: (if (is-some admin-record)
              (get role (unwrap-panic admin-record))
              "NONE")
    })
  )
)

;; Validate LEI format (public helper)
(define-read-only (validate-lei-format (lei (string-ascii 20)))
  (ok (is-valid-lei lei))
)

;; CONTRACT INITIALIZATION

;; Initialize with deployer as super admin
(begin
  (map-set admins 
    { admin: tx-sender } 
    { authorized: true, role: "SUPER" })
)
