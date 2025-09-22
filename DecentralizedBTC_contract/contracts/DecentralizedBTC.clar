
;; title: DecentralizedBTC
;; version: 1.0.0
;; summary: Cross-chain AMM liquidity pool for decentralized Bitcoin custody
;; description: A decentralized AMM that enables cross-chain Bitcoin liquidity provision
;;              with automated market making, yield farming, and decentralized custody features

;; SIP-010 compatible functions (no formal trait implementation for standalone contract)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_POOL_NOT_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u104))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u105))
(define-constant ERR_ZERO_AMOUNT (err u106))
(define-constant ERR_INVALID_TOKEN (err u107))
(define-constant ERR_POOL_EXISTS (err u108))

;; Token constants
(define-constant TOKEN_DECIMALS u8)
(define-constant TOTAL_SUPPLY u21000000000000) ;; 21M tokens with 8 decimals
(define-constant PRECISION u100000000) ;; 10^8 for calculations

;; AMM constants
(define-constant MIN_LIQUIDITY u1000)
(define-constant FEE_DENOMINATOR u10000)
(define-constant SWAP_FEE u30) ;; 0.3%

;; Data variables
(define-data-var contract-uri (optional (string-utf8 256)) none)
(define-data-var total-supply uint TOTAL_SUPPLY)
(define-data-var pool-count uint u0)
(define-data-var protocol-fee uint u10) ;; 0.1%
(define-data-var is-paused bool false)

;; Token balances
(define-map token-balances principal uint)

;; Liquidity pools: pool-id -> {token-a, token-b, reserve-a, reserve-b, total-shares}
(define-map pools
  uint
  {
    token-a: principal,
    token-b: principal,
    reserve-a: uint,
    reserve-b: uint,
    total-shares: uint,
    fee-rate: uint
  }
)

;; User liquidity positions: {user, pool-id} -> shares
(define-map liquidity-positions
  {user: principal, pool-id: uint}
  uint
)

;; Pool lookup by token pair
(define-map pool-lookup
  {token-a: principal, token-b: principal}
  uint
)

;; Cross-chain custody tracking
(define-map custody-records
  principal
  {
    btc-address: (string-ascii 64),
    stx-amount: uint,
    lock-height: uint,
    is-active: bool
  }
)

;; Yield farming rewards
(define-map farming-rewards
  {user: principal, pool-id: uint}
  {
    reward-debt: uint,
    pending-rewards: uint,
    last-claim-height: uint
  }
)

;; SIP-010 Functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR_OWNER_ONLY)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= (get-balance sender) amount) ERR_INSUFFICIENT_BALANCE)

    (map-set token-balances sender (- (get-balance sender) amount))
    (map-set token-balances recipient (+ (get-balance recipient) amount))

    (print {op: "transfer", sender: sender, recipient: recipient, amount: amount, memo: memo})
    (ok true)
  )
)

(define-read-only (get-name)
  (ok "DecentralizedBTC")
)

(define-read-only (get-symbol)
  (ok "DBTC")
)

(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS)
)

(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? token-balances account))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (var-get contract-uri))
)

;; Pool Management Functions
(define-public (create-pool (token-a principal) (token-b principal) (initial-a uint) (initial-b uint))
  (let
    (
      (pool-id (+ (var-get pool-count) u1))
      (sorted-tokens (sort-tokens token-a token-b))
      (token-a-sorted (get token-a sorted-tokens))
      (token-b-sorted (get token-b sorted-tokens))
      (initial-shares (if (< initial-a initial-b) initial-a initial-b))
    )
    (asserts! (not (var-get is-paused)) ERR_OWNER_ONLY)
    (asserts! (> initial-a u0) ERR_ZERO_AMOUNT)
    (asserts! (> initial-b u0) ERR_ZERO_AMOUNT)
    (asserts! (is-none (map-get? pool-lookup {token-a: token-a-sorted, token-b: token-b-sorted})) ERR_POOL_EXISTS)
    (asserts! (>= initial-shares MIN_LIQUIDITY) ERR_INVALID_AMOUNT)

    ;; Transfer tokens to contract
    (try! (transfer initial-a tx-sender (as-contract tx-sender) none))

    ;; Create pool
    (map-set pools pool-id {
      token-a: token-a-sorted,
      token-b: token-b-sorted,
      reserve-a: initial-a,
      reserve-b: initial-b,
      total-shares: initial-shares,
      fee-rate: SWAP_FEE
    })

    ;; Set pool lookup
    (map-set pool-lookup {token-a: token-a-sorted, token-b: token-b-sorted} pool-id)

    ;; Mint initial liquidity shares
    (map-set liquidity-positions {user: tx-sender, pool-id: pool-id} initial-shares)

    ;; Update pool count
    (var-set pool-count pool-id)

    (print {op: "create-pool", pool-id: pool-id, token-a: token-a-sorted, token-b: token-b-sorted, initial-a: initial-a, initial-b: initial-b})
    (ok pool-id)
  )
)

(define-public (add-liquidity (pool-id uint) (amount-a uint) (amount-b uint) (min-shares uint))
  (let
    (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_EXISTS))
      (reserve-a (get reserve-a pool))
      (reserve-b (get reserve-b pool))
      (total-shares (get total-shares pool))
      (shares-from-a (/ (* amount-a total-shares) reserve-a))
      (shares-from-b (/ (* amount-b total-shares) reserve-b))
      (shares-to-mint (if (<= shares-from-a shares-from-b) shares-from-a shares-from-b))
      (current-shares (default-to u0 (map-get? liquidity-positions {user: tx-sender, pool-id: pool-id})))
    )
    (asserts! (not (var-get is-paused)) ERR_OWNER_ONLY)
    (asserts! (> amount-a u0) ERR_ZERO_AMOUNT)
    (asserts! (> amount-b u0) ERR_ZERO_AMOUNT)
    (asserts! (>= shares-to-mint min-shares) ERR_SLIPPAGE_TOO_HIGH)

    ;; Transfer tokens to contract
    (try! (transfer amount-a tx-sender (as-contract tx-sender) none))

    ;; Update pool reserves
    (map-set pools pool-id (merge pool {
      reserve-a: (+ reserve-a amount-a),
      reserve-b: (+ reserve-b amount-b),
      total-shares: (+ total-shares shares-to-mint)
    }))

    ;; Update user liquidity position
    (map-set liquidity-positions {user: tx-sender, pool-id: pool-id} (+ current-shares shares-to-mint))

    (print {op: "add-liquidity", pool-id: pool-id, amount-a: amount-a, amount-b: amount-b, shares: shares-to-mint})
    (ok shares-to-mint)
  )
)

(define-public (remove-liquidity (pool-id uint) (shares uint) (min-amount-a uint) (min-amount-b uint))
  (let
    (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_EXISTS))
      (user-shares (default-to u0 (map-get? liquidity-positions {user: tx-sender, pool-id: pool-id})))
      (total-shares (get total-shares pool))
      (reserve-a (get reserve-a pool))
      (reserve-b (get reserve-b pool))
      (amount-a (/ (* shares reserve-a) total-shares))
      (amount-b (/ (* shares reserve-b) total-shares))
    )
    (asserts! (not (var-get is-paused)) ERR_OWNER_ONLY)
    (asserts! (>= user-shares shares) ERR_INSUFFICIENT_BALANCE)
    (asserts! (>= amount-a min-amount-a) ERR_SLIPPAGE_TOO_HIGH)
    (asserts! (>= amount-b min-amount-b) ERR_SLIPPAGE_TOO_HIGH)

    ;; Update pool reserves
    (map-set pools pool-id (merge pool {
      reserve-a: (- reserve-a amount-a),
      reserve-b: (- reserve-b amount-b),
      total-shares: (- total-shares shares)
    }))

    ;; Update user liquidity position
    (map-set liquidity-positions {user: tx-sender, pool-id: pool-id} (- user-shares shares))

    ;; Transfer tokens back to user
    (try! (as-contract (transfer amount-a tx-sender tx-sender none)))

    (print {op: "remove-liquidity", pool-id: pool-id, shares: shares, amount-a: amount-a, amount-b: amount-b})
    (ok {amount-a: amount-a, amount-b: amount-b})
  )
)

;; Swap Functions
(define-public (swap-exact-tokens-for-tokens (pool-id uint) (amount-in uint) (min-amount-out uint) (token-in principal))
  (let
    (
      (pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_EXISTS))
      (token-a (get token-a pool))
      (token-b (get token-b pool))
      (reserve-a (get reserve-a pool))
      (reserve-b (get reserve-b pool))
      (fee-rate (get fee-rate pool))
      (is-token-a (is-eq token-in token-a))
    )
    (asserts! (not (var-get is-paused)) ERR_OWNER_ONLY)
    (asserts! (> amount-in u0) ERR_ZERO_AMOUNT)
    (asserts! (or (is-eq token-in token-a) (is-eq token-in token-b)) ERR_INVALID_TOKEN)

    (if is-token-a
      (swap-a-for-b pool-id amount-in min-amount-out reserve-a reserve-b fee-rate)
      (swap-b-for-a pool-id amount-in min-amount-out reserve-a reserve-b fee-rate)
    )
  )
)

;; Cross-chain custody functions
(define-public (lock-btc-custody (btc-address (string-ascii 64)) (stx-amount uint))
  (begin
    (asserts! (> stx-amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= (get-balance tx-sender) stx-amount) ERR_INSUFFICIENT_BALANCE)

    ;; Lock STX tokens
    (try! (transfer stx-amount tx-sender (as-contract tx-sender) none))

    ;; Record custody
    (map-set custody-records tx-sender {
      btc-address: btc-address,
      stx-amount: stx-amount,
      lock-height: block-height,
      is-active: true
    })

    (print {op: "lock-btc-custody", user: tx-sender, btc-address: btc-address, stx-amount: stx-amount})
    (ok true)
  )
)

(define-public (unlock-btc-custody)
  (let
    (
      (custody (unwrap! (map-get? custody-records tx-sender) ERR_POOL_NOT_EXISTS))
      (stx-amount (get stx-amount custody))
    )
    (asserts! (get is-active custody) ERR_INVALID_AMOUNT)

    ;; Unlock STX tokens
    (try! (as-contract (transfer stx-amount tx-sender tx-sender none)))

    ;; Update custody record
    (map-set custody-records tx-sender (merge custody {is-active: false}))

    (print {op: "unlock-btc-custody", user: tx-sender, stx-amount: stx-amount})
    (ok stx-amount)
  )
)

;; Yield farming functions
(define-public (stake-for-rewards (pool-id uint) (amount uint))
  (let
    (
      (current-rewards (default-to {reward-debt: u0, pending-rewards: u0, last-claim-height: u0}
                       (map-get? farming-rewards {user: tx-sender, pool-id: pool-id})))
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)

    ;; Update farming rewards
    (map-set farming-rewards {user: tx-sender, pool-id: pool-id} {
      reward-debt: (+ (get reward-debt current-rewards) amount),
      pending-rewards: (get pending-rewards current-rewards),
      last-claim-height: block-height
    })

    (print {op: "stake-for-rewards", user: tx-sender, pool-id: pool-id, amount: amount})
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-pool (pool-id uint))
  (map-get? pools pool-id)
)

(define-read-only (get-user-liquidity (user principal) (pool-id uint))
  (default-to u0 (map-get? liquidity-positions {user: user, pool-id: pool-id}))
)

(define-read-only (get-pool-by-tokens (token-a principal) (token-b principal))
  (let
    (
      (sorted-tokens (sort-tokens token-a token-b))
    )
    (map-get? pool-lookup {token-a: (get token-a sorted-tokens), token-b: (get token-b sorted-tokens)})
  )
)

(define-read-only (get-custody-record (user principal))
  (map-get? custody-records user)
)

(define-read-only (calculate-swap-output (reserve-in uint) (reserve-out uint) (amount-in uint) (fee-rate uint))
  (let
    (
      (amount-in-with-fee (- amount-in (/ (* amount-in fee-rate) FEE_DENOMINATOR)))
      (numerator (* amount-in-with-fee reserve-out))
      (denominator (+ reserve-in amount-in-with-fee))
    )
    (/ numerator denominator)
  )
)

;; Private helper functions
(define-private (sort-tokens (token-a principal) (token-b principal))
  (let
    (
      (addr-a-buff (unwrap-panic (principal-destruct? token-a)))
      (addr-b-buff (unwrap-panic (principal-destruct? token-b)))
      (hash-a (get hash-bytes addr-a-buff))
      (hash-b (get hash-bytes addr-b-buff))
    )
    (if (< hash-a hash-b)
      {token-a: token-a, token-b: token-b}
      {token-a: token-b, token-b: token-a}
    )
  )
)


(define-private (swap-a-for-b (pool-id uint) (amount-in uint) (min-amount-out uint) (reserve-a uint) (reserve-b uint) (fee-rate uint))
  (let
    (
      (amount-out (calculate-swap-output reserve-a reserve-b amount-in fee-rate))
    )
    (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_TOO_HIGH)

    ;; Transfer input token to contract
    (try! (transfer amount-in tx-sender (as-contract tx-sender) none))

    ;; Update pool reserves
    (map-set pools pool-id (merge (unwrap-panic (map-get? pools pool-id)) {
      reserve-a: (+ reserve-a amount-in),
      reserve-b: (- reserve-b amount-out)
    }))

    (print {op: "swap", pool-id: pool-id, amount-in: amount-in, amount-out: amount-out})
    (ok amount-out)
  )
)

(define-private (swap-b-for-a (pool-id uint) (amount-in uint) (min-amount-out uint) (reserve-a uint) (reserve-b uint) (fee-rate uint))
  (let
    (
      (amount-out (calculate-swap-output reserve-b reserve-a amount-in fee-rate))
    )
    (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_TOO_HIGH)

    ;; Transfer input token to contract
    (try! (transfer amount-in tx-sender (as-contract tx-sender) none))

    ;; Update pool reserves
    (map-set pools pool-id (merge (unwrap-panic (map-get? pools pool-id)) {
      reserve-a: (- reserve-a amount-out),
      reserve-b: (+ reserve-b amount-in)
    }))

    (print {op: "swap", pool-id: pool-id, amount-in: amount-in, amount-out: amount-out})
    (ok amount-out)
  )
)

;; Admin functions
(define-public (set-contract-uri (uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (var-set contract-uri uri)
    (ok true)
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
    (var-set is-paused (not (var-get is-paused)))
    (ok (var-get is-paused))
  )
)

;; Initialize contract with owner balance
(map-set token-balances CONTRACT_OWNER TOTAL_SUPPLY)
