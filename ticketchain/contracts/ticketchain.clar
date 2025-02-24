;; TicketChain - Decentralized Event Ticketing System with Risk Protection
;; Description: Smart contract for minting and managing NFT event tickets with transfer restrictions and risk protection

;; Constants
(define-constant owner tx-sender)
(define-constant ERR-NOT-ALLOWED (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u101))
(define-constant ERR-SOLD-OUT (err u102))
(define-constant ERR-TRANSFER-BLOCKED (err u103))
(define-constant ERR-EVENT-ACTIVE (err u104))
(define-constant ERR-REFUND-DENIED (err u105))
(define-constant ERR-PROTECTION-USED (err u106))
(define-constant ERR-INVALID-INPUT (err u107))
(define-constant PROTECTION-RATE u5) ;; 5% of ticket price
(define-constant PROTECTION-FUND 'SP000000000000000000002Q6VF78) ;; Example fund address
(define-constant MIN-PRICE u1000) ;; Minimum ticket price
(define-constant MAX-ATTENDEES u10000) ;; Maximum tickets per event

;; Data Variables
(define-data-var next-event-id uint u1)
(define-data-var next-ticket-id uint u1)
(define-data-var protection-fund uint u0)

;; Data Maps
(define-map Events
    uint  ;; event-id
    {
        name: (string-ascii 100),
        organizer: principal,
        max-attendees: uint,
        tickets-sold: uint,
        ticket-price: uint,
        event-time: uint,
        is-cancelled: bool,
        location-info: (string-ascii 256)
    }
)

(define-map Tickets
    uint  ;; ticket-id
    {
        event-id: uint,
        owner: principal,
        is-used: bool,
        transferred: bool,
        purchase-price: uint,
        has-protection: bool,
        protection-claimed: bool,
        seat-details: (string-ascii 256)
    }
)

(define-map EventTickets
    uint  ;; event-id
    (list 500 uint)  ;; list of ticket IDs
)

;; Private Functions
(define-private (is-event-organizer (event-id uint) (caller principal))
    (let ((event (unwrap! (map-get? Events event-id) false)))
        (is-eq (get organizer event) caller)
    )
)

(define-private (calculate-protection-fee (ticket-price uint))
    (/ (* ticket-price PROTECTION-RATE) u100)
)

(define-private (process-protection-payment (protection-fee uint) (organizer principal))
    (if (> protection-fee u0)
        (begin
            (try! (stx-transfer? protection-fee organizer PROTECTION-FUND))
            (var-set protection-fund (+ (var-get protection-fund) protection-fee))
            (ok true)
        )
        (ok true)
    )
)

(define-private (validate-event-params (name (string-ascii 100)) 
                                     (max-attendees uint)
                                     (ticket-price uint)
                                     (event-time uint)
                                     (location-info (string-ascii 256)))
    (and
        (> (len name) u0)
        (<= max-attendees MAX-ATTENDEES)
        (> max-attendees u0)
        (>= ticket-price MIN-PRICE)
        (> event-time block-height)
        (> (len location-info) u0)
    )
)

;; Public Functions

;; Create a new event
(define-public (create-event (name (string-ascii 100)) 
                           (max-attendees uint) 
                           (ticket-price uint)
                           (event-time uint)
                           (location-info (string-ascii 256)))
    (let (
        (event-id (var-get next-event-id))
        (params-valid (validate-event-params name max-attendees ticket-price event-time location-info))
    )
        (asserts! params-valid ERR-INVALID-INPUT)
        
        (map-set Events
            event-id
            {
                name: name,
                organizer: tx-sender,
                max-attendees: max-attendees,
                tickets-sold: u0,
                ticket-price: ticket-price,
                event-time: event-time,
                is-cancelled: false,
                location-info: location-info
            }
        )
        (var-set next-event-id (+ event-id u1))
        (ok event-id)
    )
)

;; Purchase a ticket with optional protection
(define-public (buy-ticket (event-id uint) (with-protection bool))
    (let (
        (event (unwrap! (map-get? Events event-id) ERR-EVENT-NOT-FOUND))
        (ticket-id (var-get next-ticket-id))
        (protection-fee (if with-protection 
                          (calculate-protection-fee (get ticket-price event))
                          u0))
        (total-cost (+ (get ticket-price event) protection-fee))
    )
        (asserts! (< (get tickets-sold event) (get max-attendees event)) ERR-SOLD-OUT)
        (asserts! (not (get is-cancelled event)) ERR-EVENT-ACTIVE)
        (asserts! (< block-height (get event-time event)) ERR-INVALID-INPUT)
        
        ;; Process payment
        (try! (stx-transfer? total-cost tx-sender (get organizer event)))
        
        ;; Handle protection purchase
        (try! (process-protection-payment protection-fee (get organizer event)))
        
        ;; Mint ticket
        (map-set Tickets
            ticket-id
            {
                event-id: event-id,
                owner: tx-sender,
                is-used: false,
                transferred: false,
                purchase-price: (get ticket-price event),
                has-protection: with-protection,
                protection-claimed: false,
                seat-details: (get location-info event)
            }
        )
        
        ;; Update event records
        (map-set Events
            event-id
            (merge event { tickets-sold: (+ (get tickets-sold event) u1) })
        )
        
        ;; Add ticket to event's ticket list
        (match (map-get? EventTickets event-id)
            tickets (map-set EventTickets 
                          event-id 
                          (unwrap! (as-max-len? (append tickets ticket-id) u500) ERR-SOLD-OUT))
            (map-set EventTickets event-id (list ticket-id))
        )
        
        (var-set next-ticket-id (+ ticket-id u1))
        (ok ticket-id)
    )
)

;; Transfer ticket
(define-public (transfer-ticket (ticket-id uint) (new-owner principal))
    (let ((ticket (unwrap! (map-get? Tickets ticket-id) ERR-EVENT-NOT-FOUND)))
        (asserts! (is-eq (get owner ticket) tx-sender) ERR-NOT-ALLOWED)
        (asserts! (not (get transferred ticket)) ERR-TRANSFER-BLOCKED)
        
        (map-set Tickets
            ticket-id
            (merge ticket {
                owner: new-owner,
                transferred: true
            })
        )
        (ok true)
    )
)

;; Cancel event and enable refunds
(define-public (cancel-event (event-id uint))
    (let ((event (unwrap! (map-get? Events event-id) ERR-EVENT-NOT-FOUND)))
        (asserts! (is-event-organizer event-id tx-sender) ERR-NOT-ALLOWED)
        
        (map-set Events
            event-id
            (merge event { is-cancelled: true })
        )
        (ok true)
    )
)

;; Claim refund for canceled event
(define-public (get-refund (ticket-id uint))
    (let (
        (ticket (unwrap! (map-get? Tickets ticket-id) ERR-EVENT-NOT-FOUND))
        (event (unwrap! (map-get? Events (get event-id ticket)) ERR-EVENT-NOT-FOUND))
    )
        (asserts! (is-eq (get owner ticket) tx-sender) ERR-NOT-ALLOWED)
        (asserts! (get is-cancelled event) ERR-REFUND-DENIED)
        
        ;; Process refund
        (try! (stx-transfer? (get purchase-price ticket) 
                            (get organizer event) 
                            tx-sender))
        
        ;; Mark ticket as used
        (map-set Tickets
            ticket-id
            (merge ticket { is-used: true })
        )
        (ok true)
    )
)

;; Claim protection refund (can be used even if event is not canceled)
(define-public (use-protection (ticket-id uint))
    (let (
        (ticket (unwrap! (map-get? Tickets ticket-id) ERR-EVENT-NOT-FOUND))
    )
        (asserts! (is-eq (get owner ticket) tx-sender) ERR-NOT-ALLOWED)
        (asserts! (get has-protection ticket) ERR-REFUND-DENIED)
        (asserts! (not (get protection-claimed ticket)) ERR-PROTECTION-USED)
        
        ;; Process protection refund
        (try! (stx-transfer? (get purchase-price ticket) 
                            PROTECTION-FUND 
                            tx-sender))
        
        ;; Mark protection as used
        (map-set Tickets
            ticket-id
            (merge ticket { 
                protection-claimed: true,
                is-used: true 
            })
        )
        (ok true)
    )
)

;; Validate ticket
(define-public (verify-ticket (ticket-id uint))
    (let ((ticket (unwrap! (map-get? Tickets ticket-id) ERR-EVENT-NOT-FOUND)))
        (asserts! (is-event-organizer (get event-id ticket) tx-sender) ERR-NOT-ALLOWED)
        (asserts! (not (get is-used ticket)) ERR-REFUND-DENIED)
        
        (map-set Tickets
            ticket-id
            (merge ticket { is-used: true })
        )
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-event (event-id uint))
    (map-get? Events event-id)
)

(define-read-only (get-ticket (ticket-id uint))
    (map-get? Tickets ticket-id)
)

(define-read-only (get-event-tickets (event-id uint))
    (map-get? EventTickets event-id)
)

(define-read-only (get-protection-fee (ticket-price uint))
    (calculate-protection-fee ticket-price)
)

(define-read-only (get-protection-fund-balance)
    (var-get protection-fund)
)
