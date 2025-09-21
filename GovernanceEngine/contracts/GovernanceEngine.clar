;; Governance Proposal Filtering and Prioritization Engine
;; A sophisticated smart contract that automatically evaluates, filters, and prioritizes
;; governance proposals based on multiple criteria including community impact, technical
;; feasibility, financial implications, and stakeholder voting power. The system implements
;; advanced scoring algorithms to ensure the most valuable proposals receive priority.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u400))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u401))
(define-constant ERR-INVALID-SCORE (err u402))
(define-constant ERR-PROPOSAL-EXPIRED (err u403))
(define-constant ERR-INSUFFICIENT-STAKE (err u404))
(define-constant MIN-PROPOSAL-STAKE u1000000) ;; 1 STX minimum stake
(define-constant MAX-PROPOSALS-PER-CYCLE u50) ;; Maximum proposals per governance cycle
(define-constant PROPOSAL-VALIDITY-PERIOD u1008) ;; 7 days in blocks
(define-constant MIN-COMMUNITY-SCORE u60) ;; Minimum 60% community score
(define-constant TECHNICAL-WEIGHT u30) ;; 30% weight for technical feasibility
(define-constant FINANCIAL-WEIGHT u25) ;; 25% weight for financial impact
(define-constant COMMUNITY-WEIGHT u45) ;; 45% weight for community support

;; data maps and vars
(define-data-var next-proposal-id uint u1)
(define-data-var governance-cycle-count uint u0)
(define-data-var total-active-proposals uint u0)
(define-data-var emergency-mode bool false)

(define-map proposals
  uint ;; proposal-id
  {
    creator: principal,
    title: (string-ascii 100),
    category: (string-ascii 20),
    stake-amount: uint,
    submission-block: uint,
    status: (string-ascii 20),
    community-score: uint,
    technical-score: uint,
    financial-score: uint,
    priority-rank: uint,
    total-votes: uint
  })

(define-map proposal-metrics
  uint ;; proposal-id
  {
    complexity-score: uint,
    implementation-cost: uint,
    risk-assessment: uint,
    timeline-estimate: uint,
    resource-requirements: uint,
    stakeholder-impact: uint,
    innovation-factor: uint,
    sustainability-score: uint
  })

(define-map governance-evaluators
  principal
  {
    authorized: bool,
    expertise-areas: (list 5 (string-ascii 20)),
    evaluation-count: uint,
    accuracy-rating: uint
  })

;; private functions
(define-private (calculate-composite-score (community uint) (technical uint) (financial uint))
  (/ (+ (* community COMMUNITY-WEIGHT)
        (* technical TECHNICAL-WEIGHT)
        (* financial FINANCIAL-WEIGHT)) u100))

(define-private (validate-proposal-eligibility (creator principal) (stake uint))
  (and (>= stake MIN-PROPOSAL-STAKE)
       (< (var-get total-active-proposals) MAX-PROPOSALS-PER-CYCLE)
       (not (var-get emergency-mode))))

(define-private (is-proposal-expired (proposal-id uint))
  (match (map-get? proposals proposal-id)
    some-proposal 
      (> (- block-height (get submission-block some-proposal)) PROPOSAL-VALIDITY-PERIOD)
    true))

(define-private (update-priority-rankings)
  (begin
    ;; This would iterate through proposals and update rankings
    ;; Simplified implementation for demonstration
    (var-set governance-cycle-count (+ (var-get governance-cycle-count) u1))
    true))

;; public functions
(define-public (authorize-evaluator 
  (evaluator principal) 
  (expertise (list 5 (string-ascii 20))))
  
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set governance-evaluators evaluator {
      authorized: true,
      expertise-areas: expertise,
      evaluation-count: u0,
      accuracy-rating: u100
    })
    (ok true)))

(define-public (submit-proposal
  (title (string-ascii 100))
  (category (string-ascii 20))
  (stake-amount uint))
  
  (let ((proposal-id (var-get next-proposal-id)))
    (asserts! (validate-proposal-eligibility tx-sender stake-amount) ERR-INSUFFICIENT-STAKE)
    
    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Create proposal record
    (map-set proposals proposal-id {
      creator: tx-sender,
      title: title,
      category: category,
      stake-amount: stake-amount,
      submission-block: block-height,
      status: "SUBMITTED",
      community-score: u0,
      technical-score: u0,
      financial-score: u0,
      priority-rank: u999,
      total-votes: u0
    })
    
    ;; Initialize metrics
    (map-set proposal-metrics proposal-id {
      complexity-score: u50,
      implementation-cost: u0,
      risk-assessment: u50,
      timeline-estimate: u30,
      resource-requirements: u50,
      stakeholder-impact: u50,
      innovation-factor: u50,
      sustainability-score: u50
    })
    
    (var-set next-proposal-id (+ proposal-id u1))
    (var-set total-active-proposals (+ (var-get total-active-proposals) u1))
    
    (ok proposal-id)))

(define-public (evaluate-proposal
  (proposal-id uint)
  (community-score uint)
  (technical-score uint)
  (financial-score uint))
  
  (let ((evaluator (map-get? governance-evaluators tx-sender))
        (proposal (map-get? proposals proposal-id)))
    
    (asserts! 
      (match evaluator
        some-eval (get authorized some-eval)
        false) 
      ERR-UNAUTHORIZED)
    
    (asserts! (is-some proposal) ERR-PROPOSAL-NOT-FOUND)
    (asserts! (not (is-proposal-expired proposal-id)) ERR-PROPOSAL-EXPIRED)
    (asserts! (and (<= community-score u100) (<= technical-score u100) (<= financial-score u100))
              ERR-INVALID-SCORE)
    
    (match proposal
      some-prop
        (let ((composite-score (calculate-composite-score community-score technical-score financial-score)))
          ;; Update proposal scores
          (map-set proposals proposal-id (merge some-prop {
            community-score: community-score,
            technical-score: technical-score,
            financial-score: financial-score,
            status: (if (>= community-score MIN-COMMUNITY-SCORE) "QUALIFIED" "FILTERED")
          }))
          
          ;; Update evaluator stats
          (match evaluator
            some-eval 
              (map-set governance-evaluators tx-sender (merge some-eval {
                evaluation-count: (+ (get evaluation-count some-eval) u1)
              }))
            false)
          
          (ok composite-score))
      ERR-PROPOSAL-NOT-FOUND)))


