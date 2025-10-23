;; Crowdfunding Platform Contract
;; A decentralized crowdfunding platform with milestone-based funding

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-PROJECT-NOT-FOUND (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-PROJECT-ENDED (err u403))
(define-constant ERR-GOAL-NOT-REACHED (err u404))
(define-constant ERR-ALREADY-WITHDRAWN (err u405))
(define-constant ERR-INVALID-MILESTONE (err u406))
(define-constant ERR-REFUND-PERIOD-ENDED (err u407))
(define-constant ERR-MILESTONE-ARRAYS-MISMATCH (err u408))
(define-constant ERR-INVALID-MILESTONE-TARGET (err u409))
(define-constant ERR-MILESTONE-NOT-COMPLETED (err u410))
(define-constant ERR-INSUFFICIENT-FUNDS (err u411))

;; Constants
(define-constant PROJECT-ACTIVE u0)
(define-constant PROJECT-SUCCESSFUL u1)
(define-constant PROJECT-FAILED u2)
(define-constant PROJECT-WITHDRAWN u3)

(define-constant MAX-MILESTONES u5)

;; Data variables
(define-data-var project-counter uint u0)
(define-data-var platform-fee uint u300) ;; 3% fee (300 basis points)
(define-data-var contract-owner principal tx-sender)

;; Data maps
(define-map projects
  { project-id: uint }
  {
    creator: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    goal: uint,
    raised: uint,
    deadline: uint,
    status: uint,
    created-at: uint,
    withdrawn: bool
  }
)

(define-map contributions
  { project-id: uint, contributor: principal }
  { 
    amount: uint,
    timestamp: uint,
    refunded: bool
  }
)

(define-map project-backers
  { project-id: uint }
  { count: uint }
)

(define-map milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-utf8 200),
    target-amount: uint,
    completed: bool,
    withdrawn: bool
  }
)

(define-map milestone-count
  { project-id: uint }
  { count: uint }
)

;; Private helper function to create a single milestone
(define-private (create-single-milestone
  (milestone-id uint)
  (context { 
    project-id: uint, 
    descriptions: (list 5 (string-utf8 200)),
    targets: (list 5 uint),
    current-index: uint,
    success: bool
  })
)
  (let
    (
      (description (unwrap! (element-at (get descriptions context) (get current-index context)) context))
      (target (unwrap! (element-at (get targets context) (get current-index context)) context))
    )
    (if (get success context)
      (begin
        (map-set milestones
          { project-id: (get project-id context), milestone-id: milestone-id }
          {
            description: description,
            target-amount: target,
            completed: false,
            withdrawn: false
          }
        )
        (merge context { current-index: (+ (get current-index context) u1), success: true })
      )
      context
    )
  )
)

;; Validate milestone targets sum up reasonably
(define-private (validate-milestone-targets
  (targets (list 5 uint))
  (goal uint)
)
  (let
    (
      (total-target (fold + targets u0))
    )
    ;; Ensure milestone targets are reasonable (not exceeding 2x the goal)
    (and 
      (> total-target u0)
      (<= total-target (* goal u2))
    )
  )
)

;; Create a new project
(define-public (create-project 
  (title (string-utf8 100))
  (description (string-utf8 500))
  (goal uint)
  (duration uint)
  (milestone-descriptions (list 5 (string-utf8 200)))
  (milestone-targets (list 5 uint))
)
  (let
    (
      (project-id (+ (var-get project-counter) u1))
      (deadline (+ block-height duration))
      (milestone-count-value (len milestone-descriptions))
    )
    ;; Validate inputs
    (asserts! (> goal u0) ERR-INVALID-AMOUNT)
    (asserts! (> duration u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq milestone-count-value (len milestone-targets)) ERR-MILESTONE-ARRAYS-MISMATCH)
    (asserts! (and (> milestone-count-value u0) (<= milestone-count-value MAX-MILESTONES)) ERR-INVALID-MILESTONE)
    (asserts! (validate-milestone-targets milestone-targets goal) ERR-INVALID-MILESTONE-TARGET)
    
    ;; Create project
    (map-set projects
      { project-id: project-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        goal: goal,
        raised: u0,
        deadline: deadline,
        status: PROJECT-ACTIVE,
        created-at: block-height,
        withdrawn: false
      }
    )
    
    (map-set project-backers
      { project-id: project-id }
      { count: u0 }
    )
    
    (map-set milestone-count
      { project-id: project-id }
      { count: milestone-count-value }
    )
    
    ;; Create milestones using fold with indexed approach
    (fold create-single-milestone
      (list u1 u2 u3 u4 u5)
      {
        project-id: project-id,
        descriptions: milestone-descriptions,
        targets: milestone-targets,
        current-index: u0,
        success: true
      }
    )
    
    (var-set project-counter project-id)
    (ok project-id)
  )
)

;; Contribute to a project
(define-public (contribute (project-id uint) (amount uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (existing-contribution (default-to { amount: u0, timestamp: u0, refunded: false } 
        (map-get? contributions { project-id: project-id, contributor: tx-sender })))
      (backers-data (unwrap! (map-get? project-backers { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (is-new-backer (is-eq (get amount existing-contribution) u0))
      (new-total (+ (get raised project-data) amount))
    )
    ;; Validate contribution
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq (get status project-data) PROJECT-ACTIVE) ERR-PROJECT-ENDED)
    (asserts! (<= block-height (get deadline project-data)) ERR-PROJECT-ENDED)
    (asserts! (>= (stx-get-balance tx-sender) amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer funds to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update contribution
    (map-set contributions
      { project-id: project-id, contributor: tx-sender }
      {
        amount: (+ (get amount existing-contribution) amount),
        timestamp: block-height,
        refunded: false
      }
    )
    
    ;; Update project raised amount
    (map-set projects
      { project-id: project-id }
      (merge project-data { raised: new-total })
    )
    
    ;; Update backer count if new backer
    (if is-new-backer
      (map-set project-backers
        { project-id: project-id }
        { count: (+ (get count backers-data) u1) }
      )
      true
    )
    
    (ok true)
  )
)

;; Withdraw funds (milestone-based)
(define-public (withdraw-milestone (project-id uint) (milestone-id uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (milestone-data (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE))
      (milestone-count-data (unwrap! (map-get? milestone-count { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (platform-fee-amount (/ (* (get target-amount milestone-data) (var-get platform-fee)) u10000))
      (creator-amount (- (get target-amount milestone-data) platform-fee-amount))
    )
    ;; Validate withdrawal
    (asserts! (is-eq tx-sender (get creator project-data)) ERR-NOT-AUTHORIZED)
    (asserts! (<= milestone-id (get count milestone-count-data)) ERR-INVALID-MILESTONE)
    (asserts! (>= (get raised project-data) (get target-amount milestone-data)) ERR-GOAL-NOT-REACHED)
    (asserts! (not (get withdrawn milestone-data)) ERR-ALREADY-WITHDRAWN)
    (asserts! (> creator-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Ensure contract has sufficient balance
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) (get target-amount milestone-data)) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer funds to creator
    (try! (as-contract (stx-transfer? creator-amount tx-sender (get creator project-data))))
    
    ;; Transfer platform fee to contract owner
    (if (> platform-fee-amount u0)
      (try! (as-contract (stx-transfer? platform-fee-amount tx-sender (var-get contract-owner))))
      true
    )
    
    ;; Mark milestone as withdrawn and completed
    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone-data { withdrawn: true, completed: true })
    )
    
    (ok true)
  )
)

;; Request refund (if project failed)
(define-public (request-refund (project-id uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (contribution (unwrap! (map-get? contributions { project-id: project-id, contributor: tx-sender }) ERR-INVALID-AMOUNT))
      (refund-amount (get amount contribution))
    )
    ;; Validate refund request
    (asserts! (> refund-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (get refunded contribution)) ERR-ALREADY-WITHDRAWN)
    (asserts! 
      (or 
        (> block-height (get deadline project-data))
        (is-eq (get status project-data) PROJECT-FAILED)
      ) 
      ERR-REFUND-PERIOD-ENDED
    )
    (asserts! (< (get raised project-data) (get goal project-data)) ERR-GOAL-NOT-REACHED)
    
    ;; Ensure contract has sufficient balance
    (asserts! (>= (stx-get-balance (as-contract tx-sender)) refund-amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer refund to contributor
    (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
    
    ;; Mark as refunded
    (map-set contributions
      { project-id: project-id, contributor: tx-sender }
      (merge contribution { refunded: true })
    )
    
    (ok true)
  )
)

;; Mark project as successful (when goal is reached)
(define-public (mark-project-successful (project-id uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
    )
    (asserts! (>= (get raised project-data) (get goal project-data)) ERR-GOAL-NOT-REACHED)
    (asserts! (is-eq (get status project-data) PROJECT-ACTIVE) ERR-PROJECT-ENDED)
    
    (map-set projects
      { project-id: project-id }
      (merge project-data { status: PROJECT-SUCCESSFUL })
    )
    
    (ok true)
  )
)

;; Mark project as failed (after deadline)
(define-public (mark-project-failed (project-id uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
    )
    (asserts! (> block-height (get deadline project-data)) ERR-PROJECT-ENDED)
    (asserts! (< (get raised project-data) (get goal project-data)) ERR-GOAL-NOT-REACHED)
    (asserts! (is-eq (get status project-data) PROJECT-ACTIVE) ERR-PROJECT-ENDED)
    
    (map-set projects
      { project-id: project-id }
      (merge project-data { status: PROJECT-FAILED })
    )
    
    (ok true)
  )
)

;; Update platform fee (owner only)
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-AMOUNT) ;; Max 10% fee
    (var-set platform-fee new-fee)
    (ok true)
  )
)

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (get-contribution (project-id uint) (contributor principal))
  (map-get? contributions { project-id: project-id, contributor: contributor })
)

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-milestone-count (project-id uint))
  (map-get? milestone-count { project-id: project-id })
)

(define-read-only (get-project-backers (project-id uint))
  (map-get? project-backers { project-id: project-id })
)

(define-read-only (get-project-count)
  (var-get project-counter)
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (is-project-successful (project-id uint))
  (match (map-get? projects { project-id: project-id })
    project-data (>= (get raised project-data) (get goal project-data))
    false
  )
)

(define-read-only (get-project-progress (project-id uint))
  (match (map-get? projects { project-id: project-id })
    project-data 
      (if (> (get goal project-data) u0)
        (ok (/ (* (get raised project-data) u100) (get goal project-data)))
        ERR-INVALID-AMOUNT
      )
    ERR-PROJECT-NOT-FOUND
  )
)

(define-read-only (is-deadline-passed (project-id uint))
  (match (map-get? projects { project-id: project-id })
    project-data (> block-height (get deadline project-data))
    false
  )
)

(define-read-only (can-withdraw-milestone (project-id uint) (milestone-id uint))
  (match (map-get? projects { project-id: project-id })
    project-data
      (match (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
        milestone-data
          (and
            (>= (get raised project-data) (get target-amount milestone-data))
            (not (get withdrawn milestone-data))
          )
        false
      )
    false
  )
)
