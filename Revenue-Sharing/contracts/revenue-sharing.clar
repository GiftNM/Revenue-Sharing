;; Revenue Sharing Contract
;; Transparent on-chain revenue distribution protocol on Stacks

;; Constants
(define-constant REVENUE-MANAGER tx-sender)
(define-constant ERR-MANAGER-ONLY (err u700))
(define-constant ERR-REVENUE-DEPLETED (err u701))
(define-constant ERR-DISTRIBUTION-PENDING (err u702))
(define-constant ERR-NULL-CONTRIBUTION (err u703))
(define-constant ERR-ALLOCATION-REJECTED (err u704))
(define-constant ERR-PERIOD-CLOSED (err u705))
(define-constant ERR-STAKE-INSUFFICIENT (err u706))
(define-constant ERR-DISTRIBUTION-HALTED (err u707))
(define-constant ERR-UNIT-CALC-ERROR (err u708))
(define-constant ERR-PAYOUT-DEFICIT (err u709))
(define-constant ERR-TRANSFER-ERROR (err u710))

;; Platform retention rate: 0.04% = 4 basis points
(define-constant RETENTION-RATE u4)
(define-constant UNIT-BASE u10000)

;; Data Variables
(define-data-var revenue-pool uint u0)
(define-data-var total-distributed uint u0)
(define-data-var distribution-halted bool false)
(define-data-var distribution-active bool false)

;; Maps
(define-map stakeholder-contributions principal uint)
(define-map stakeholder-units principal uint)

;; Distribution period counter
(define-data-var distribution-period uint u0)

;; Read-only functions
(define-read-only (get-stakeholder-contribution (stakeholder principal))
  (default-to u0 (map-get? stakeholder-contributions stakeholder))
)

(define-read-only (get-stakeholder-units (stakeholder principal))
  (default-to u0 (map-get? stakeholder-units stakeholder))
)

(define-read-only (get-revenue-pool)
  (var-get revenue-pool)
)

(define-read-only (get-total-distributed)
  (var-get total-distributed)
)

(define-read-only (calculate-retention (amount uint))
  (/ (* amount RETENTION-RATE) UNIT-BASE)
)

(define-read-only (get-pool-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (is-distribution-halted)
  (var-get distribution-halted)
)

;; Private functions
(define-private (allocate-units (stakeholder principal) (contribution uint))
  (let ((current-units (get-stakeholder-units stakeholder))
        (pool-total (var-get revenue-pool))
        (live-pool (get-pool-balance)))
    (if (is-eq live-pool u0)
        ERR-UNIT-CALC-ERROR
        (let ((unit-grant (if (is-eq pool-total u0)
                              contribution
                              (/ (* contribution pool-total) live-pool))))
          (map-set stakeholder-units stakeholder (+ current-units unit-grant))
          (ok unit-grant))))
)

(define-private (burn-units (stakeholder principal) (units uint))
  (let ((current-units (get-stakeholder-units stakeholder)))
    (if (>= current-units units)
        (begin
          (map-set stakeholder-units stakeholder (- current-units units))
          (ok true))
        ERR-STAKE-INSUFFICIENT))
)

;; Public functions

;; Contribute revenue to the sharing pool
(define-public (contribute-revenue (amount uint))
  (let ((existing-contribution (get-stakeholder-contribution tx-sender)))
    (if (var-get distribution-halted)
        ERR-DISTRIBUTION-HALTED
        (begin
          (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
          (map-set stakeholder-contributions tx-sender (+ existing-contribution amount))
          (var-set revenue-pool (+ (var-get revenue-pool) amount))
          (try! (allocate-units tx-sender amount))
          (ok true))))
)

;; Claim revenue share by redeeming units
(define-public (claim-revenue-share (units uint))
  (let ((stakeholder-unit-balance (get-stakeholder-units tx-sender))
        (pool-total (var-get revenue-pool))
        (payout (if (is-eq pool-total u0)
                    u0
                    (/ (* units (get-pool-balance)) pool-total))))
    (if (> units stakeholder-unit-balance)
        ERR-STAKE-INSUFFICIENT
        (begin
          (try! (burn-units tx-sender units))
          (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
          (let ((recorded-contribution (get-stakeholder-contribution tx-sender)))
            (map-set stakeholder-contributions tx-sender (if (>= recorded-contribution payout)
                                                             (- recorded-contribution payout)
                                                             u0)))
          (var-set revenue-pool (if (>= (var-get revenue-pool) payout)
                                    (- (var-get revenue-pool) payout)
                                    u0))
          (var-set total-distributed (+ (var-get total-distributed) payout))
          (ok payout))))
)

;; Pay into revenue pool with platform retention
(define-public (pay-into-pool (amount uint))
  (let ((retention (calculate-retention amount))
        (net-payment (+ amount retention)))
    (stx-transfer? net-payment tx-sender (as-contract tx-sender)))
)

;; Halt or resume distributions (manager only)
(define-public (set-distribution-halted (halted bool))
  (if (is-eq tx-sender REVENUE-MANAGER)
      (begin
        (var-set distribution-halted halted)
        (ok true))
      ERR-MANAGER-ONLY)
)

;; Extract platform retention (manager only)
(define-public (extract-retention (amount uint))
  (if (is-eq tx-sender REVENUE-MANAGER)
      (let ((pool-balance (var-get revenue-pool)))
        (if (> amount pool-balance)
            ERR-PAYOUT-DEFICIT
            (begin
              (try! (as-contract (stx-transfer? amount tx-sender REVENUE-MANAGER)))
              (var-set revenue-pool (- pool-balance amount))
              (ok true))))
      ERR-MANAGER-ONLY)
)

;; Emergency pool recovery (manager only)
(define-public (recover-pool-funds (amount uint))
  (if (is-eq tx-sender REVENUE-MANAGER)
      (as-contract (stx-transfer? amount tx-sender REVENUE-MANAGER))
      ERR-MANAGER-ONLY)
)