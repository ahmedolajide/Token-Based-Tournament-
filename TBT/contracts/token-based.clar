;; Token-Based Tournament Contract
;; A robust tournament system with entry fees, rewards, and comprehensive state management

;; Error constants
(define-constant ERR_NOT_OWNER (err u100))
(define-constant ERR_NOT_PARTICIPANT (err u101))
(define-constant ERR_TOURNAMENT_NOT_OPEN (err u102))
(define-constant ERR_TOURNAMENT_NOT_ACTIVE (err u103))
(define-constant ERR_TOURNAMENT_NOT_ENDED (err u104))
(define-constant ERR_INSUFFICIENT_BALANCE (err u105))
(define-constant ERR_ALREADY_REGISTERED (err u106))
(define-constant ERR_INVALID_WINNER (err u107))
(define-constant ERR_ALREADY_CLAIMED (err u108))
(define-constant ERR_INVALID_TOURNAMENT (err u109))
(define-constant ERR_TOURNAMENT_FULL (err u110))

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Tournament states
(define-constant STATE_OPEN u1)
(define-constant STATE_ACTIVE u2)
(define-constant STATE_ENDED u3)
(define-constant STATE_CANCELLED u4)

;; Data variables
(define-data-var tournament-id-nonce uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points

;; Tournament structure
(define-map tournaments uint {
    owner: principal,
    entry-fee: uint,
    max-participants: uint,
    current-participants: uint,
    prize-pool: uint,
    state: uint,
    winner: (optional principal),
    start-time: uint,
    end-time: uint
})

;; Participant tracking
(define-map participants {tournament-id: uint, participant: principal} {
    registered: bool,
    eliminated: bool,
    reward-claimed: bool
})

;; Tournament participant lists
(define-map tournament-participants uint (list 100 principal))

;; Participant balances for refunds
(define-map participant-balances principal uint)

;; Helper function to get current block height
(define-read-only (get-block-height)
    block-height
)

;; Create new tournament
(define-public (create-tournament (entry-fee uint) (max-participants uint) (duration uint))
    (let ((tournament-id (+ (var-get tournament-id-nonce) u1))
          (start-time (get-block-height))
          (end-time (+ (get-block-height) duration)))
        (asserts! (<= max-participants u100) ERR_INVALID_TOURNAMENT)
        (asserts! (> entry-fee u0) ERR_INVALID_TOURNAMENT)
        (asserts! (> duration u0) ERR_INVALID_TOURNAMENT)
        
        (map-set tournaments tournament-id {
            owner: tx-sender,
            entry-fee: entry-fee,
            max-participants: max-participants,
            current-participants: u0,
            prize-pool: u0,
            state: STATE_OPEN,
            winner: none,
            start-time: start-time,
            end-time: end-time
        })
        
        (map-set tournament-participants tournament-id (list))
        (var-set tournament-id-nonce tournament-id)
        (ok tournament-id)
    )
)

;; Register for tournament
(define-public (register-tournament (tournament-id uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR_INVALID_TOURNAMENT))
          (participant-key {tournament-id: tournament-id, participant: tx-sender}))
        
        (asserts! (is-eq (get state tournament) STATE_OPEN) ERR_TOURNAMENT_NOT_OPEN)
        (asserts! (< (get current-participants tournament) (get max-participants tournament)) ERR_TOURNAMENT_FULL)
        (asserts! (is-none (map-get? participants participant-key)) ERR_ALREADY_REGISTERED)
        (asserts! (>= (stx-get-balance tx-sender) (get entry-fee tournament)) ERR_INSUFFICIENT_BALANCE)
        
        ;; Transfer entry fee
        (try! (stx-transfer? (get entry-fee tournament) tx-sender (as-contract tx-sender)))
        
        ;; Update participant balance for potential refunds
        (map-set participant-balances tx-sender 
            (+ (default-to u0 (map-get? participant-balances tx-sender)) (get entry-fee tournament)))
        
        ;; Register participant
        (map-set participants participant-key {
            registered: true,
            eliminated: false,
            reward-claimed: false
        })
        
        ;; Update tournament data
        (map-set tournaments tournament-id (merge tournament {
            current-participants: (+ (get current-participants tournament) u1),
            prize-pool: (+ (get prize-pool tournament) (get entry-fee tournament))
        }))
        
        ;; Add to participant list
        (let ((current-list (default-to (list) (map-get? tournament-participants tournament-id))))
            (map-set tournament-participants tournament-id 
                (unwrap! (as-max-len? (append current-list tx-sender) u100) ERR_TOURNAMENT_FULL))
        )
        
        (ok true)
    )
)

;; Start tournament (only owner can call)
(define-public (start-tournament (tournament-id uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR_INVALID_TOURNAMENT)))
        (asserts! (is-eq tx-sender (get owner tournament)) ERR_NOT_OWNER)
        (asserts! (is-eq (get state tournament) STATE_OPEN) ERR_TOURNAMENT_NOT_OPEN)
        (asserts! (> (get current-participants tournament) u1) ERR_INVALID_TOURNAMENT)
        
        (map-set tournaments tournament-id (merge tournament {
            state: STATE_ACTIVE
        }))
        (ok true)
    )
)

;; Declare winner and end tournament
(define-public (declare-winner (tournament-id uint) (winner principal))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR_INVALID_TOURNAMENT))
          (participant-key {tournament-id: tournament-id, participant: winner}))
        
        (asserts! (is-eq tx-sender (get owner tournament)) ERR_NOT_OWNER)
        (asserts! (is-eq (get state tournament) STATE_ACTIVE) ERR_TOURNAMENT_NOT_ACTIVE)
        (asserts! (is-some (map-get? participants participant-key)) ERR_INVALID_WINNER)
        
        (map-set tournaments tournament-id (merge tournament {
            state: STATE_ENDED,
            winner: (some winner)
        }))
        (ok true)
    )
)

;; Claim rewards (winner gets prize pool minus platform fee)
(define-public (claim-reward (tournament-id uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR_INVALID_TOURNAMENT))
          (participant-key {tournament-id: tournament-id, participant: tx-sender})
          (participant-data (unwrap! (map-get? participants participant-key) ERR_NOT_PARTICIPANT)))
        
        (asserts! (is-eq (get state tournament) STATE_ENDED) ERR_TOURNAMENT_NOT_ENDED)
        (asserts! (is-eq (some tx-sender) (get winner tournament)) ERR_INVALID_WINNER)
        (asserts! (not (get reward-claimed participant-data)) ERR_ALREADY_CLAIMED)
        
        (let ((platform-fee (/ (* (get prize-pool tournament) (var-get platform-fee-rate)) u10000))
              (winner-reward (- (get prize-pool tournament) platform-fee)))
            
            ;; Transfer reward to winner
            (try! (as-contract (stx-transfer? winner-reward tx-sender tx-sender)))
            
            ;; Transfer platform fee to contract owner
            (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))
            
            ;; Mark reward as claimed
            (map-set participants participant-key (merge participant-data {
                reward-claimed: true
            }))
            
            (ok winner-reward)
        )
    )
)

;; Cancel tournament (only owner, only if not started)
(define-public (cancel-tournament (tournament-id uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR_INVALID_TOURNAMENT)))
        (asserts! (is-eq tx-sender (get owner tournament)) ERR_NOT_OWNER)
        (asserts! (is-eq (get state tournament) STATE_OPEN) ERR_TOURNAMENT_NOT_OPEN)
        
        (map-set tournaments tournament-id (merge tournament {
            state: STATE_CANCELLED
        }))
        (ok true)
    )
)

;; Refund participants (for cancelled tournaments)
(define-public (claim-refund (tournament-id uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR_INVALID_TOURNAMENT))
          (participant-key {tournament-id: tournament-id, participant: tx-sender})
          (participant-data (unwrap! (map-get? participants participant-key) ERR_NOT_PARTICIPANT)))
        
        (asserts! (is-eq (get state tournament) STATE_CANCELLED) ERR_TOURNAMENT_NOT_ACTIVE)
        (asserts! (not (get reward-claimed participant-data)) ERR_ALREADY_CLAIMED)
        
        ;; Transfer refund
        (try! (as-contract (stx-transfer? (get entry-fee tournament) tx-sender tx-sender)))
        
        ;; Mark as claimed to prevent double refund
        (map-set participants participant-key (merge participant-data {
            reward-claimed: true
        }))
        
        (ok (get entry-fee tournament))
    )
)

;; Read-only functions
(define-read-only (get-tournament (tournament-id uint))
    (map-get? tournaments tournament-id)
)

(define-read-only (get-participant-status (tournament-id uint) (participant principal))
    (map-get? participants {tournament-id: tournament-id, participant: participant})
)

(define-read-only (get-tournament-participants (tournament-id uint))
    (map-get? tournament-participants tournament-id)
)

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate)
)

(define-read-only (get-current-tournament-id)
    (var-get tournament-id-nonce)
)

;; Admin function to update platform fee (only contract owner)
(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
        (asserts! (<= new-rate u1000) ERR_INVALID_TOURNAMENT) ;; Max 10%
        (var-set platform-fee-rate new-rate)
        (ok true)
    )
)