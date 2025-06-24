;; Fungible token trait
(define-trait ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Constants
(define-constant max-swaps u1000)
(define-constant status-pending u0)
(define-constant status-ready u1)
(define-constant status-complete u2)
(define-constant status-cancelled u3)

(define-constant contract-admin 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Variables
(define-data-var swap-counter uint u0)

;; Swap map
(define-map swaps
  {id: uint}
  {
    initiator: principal,
    counterparty: principal,
    stx-amount: uint,
    token-contract: principal,
    token-amount: uint,
    timeout-block: uint,
    status: uint
  }
)

;; Error codes
(define-constant ERR-INVALID-ID (err u1000))
(define-constant ERR-INVALID-COUNTERPARTY (err u1001))
(define-constant ERR-INVALID-TOKEN-AMOUNT (err u1002))
(define-constant ERR-INVALID-TIMEOUT (err u1003))
(define-constant ERR-INVALID-TOKEN (err u1004))

;; Helper functions for validation
(define-private (validate-swap-params 
    (counterparty principal)
    (token-contract <ft-trait>)
    (token-amount uint)
    (timeout-block uint))
    (begin
      (asserts! (> token-amount u0) ERR-INVALID-TOKEN-AMOUNT)
      (asserts! (> timeout-block stacks-block-height) ERR-INVALID-TIMEOUT)
      (asserts! (not (is-eq none (some (contract-of token-contract)))) ERR-INVALID-TOKEN)
      (ok true)))

;; Create a new swap
(define-public (create-swap
    (counterparty principal)
    (token-contract <ft-trait>)
    (token-amount uint)
    (timeout-block uint))
  (let (
        (id (var-get swap-counter))
        (sent-stx (stx-get-balance tx-sender))
      )
    (try! (validate-swap-params counterparty token-contract token-amount timeout-block))
    (if (is-eq sent-stx u0)
        (err u100)
        (begin
          (map-set swaps
            {id: id}
            {
              initiator: tx-sender,
              counterparty: counterparty,
              stx-amount: sent-stx,
              token-contract: tx-sender,
              token-amount: token-amount,
              timeout-block: timeout-block,
              status: status-pending
            })
          (var-set swap-counter (+ id u1))
          (ok id)))))

;; Get swap info
(define-read-only (get-swap (id uint))
  (map-get? swaps {id: id})
)

;; Mark swap as ready
(define-public (mark-ready (id uint))
  (match (map-get? swaps {id: id})
    swap
    (if (is-eq (get initiator swap) tx-sender)
        (begin
          (map-set swaps {id: id} (merge swap {status: status-ready}))
          (ok true))
        (err u101))
    (err u102)))

;; Claim the swap
(define-public (claim-swap (id uint) (token-contract-trait <ft-trait>))
  (match (map-get? swaps {id: id})
    swap
    (if (not (is-eq (get status swap) status-ready))
        (err u103)
        (if (not (is-eq tx-sender (get counterparty swap)))
            (err u104)
            (let (
                  (token-amount (get token-amount swap))
                  (initiator (get initiator swap))
                  (stx-amount (get stx-amount swap))
                  (counterparty (get counterparty swap))
                  (token-contract (get token-contract swap))
                 )
              (if (not (is-eq token-contract tx-sender))
                  (err u105)
                  (begin
                    ;; Transfer tokens to initiator
                    (try! (contract-call? token-contract-trait transfer 
                                        token-amount 
                                        tx-sender 
                                        initiator 
                                        none))
                    ;; Transfer STX to counterparty
                    (match (stx-transfer? stx-amount initiator counterparty)
                      success (begin
                        ;; Update swap status
                        (map-set swaps {id: id} (merge swap {status: status-complete}))
                        (ok true))
                      error (err u106)))))))
    (err u102)))

;; Cancel after timeout
(define-public (cancel-swap (id uint))
  (match (map-get? swaps {id: id})
    swap
    (if (is-eq tx-sender (get initiator swap))
        (if (>= burn-block-height (get timeout-block swap))
            (begin
              (match (stx-transfer? (get stx-amount swap) tx-sender tx-sender)
                success-result (begin
                  (map-set swaps {id: id} (merge swap {status: status-cancelled}))
                  (ok true))
                error-code (err error-code)))
            (err u106))
        (err u107))
    (err u102)))

;; Admin emergency cancel
(define-public (admin-cancel (id uint))
  (if (is-eq tx-sender contract-admin)
      (match (map-get? swaps {id: id})
        swap
        (begin
          (match (stx-transfer? (get stx-amount swap) tx-sender (get initiator swap))
            success-result (begin
              (map-set swaps {id: id} (merge swap {status: status-cancelled}))
              (ok true))
            error-code (err error-code)))
        (err u102))
      (err u108)))
