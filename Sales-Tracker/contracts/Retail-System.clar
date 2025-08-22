;; Retail Analytics Platform Smart Contract
;; A comprehensive platform for tracking retail sales, products, and customer analytics
;; Addresses compiler warnings about potentially unchecked data

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INVALID-PRICE (err u104))
(define-constant ERR-INSUFFICIENT-STOCK (err u105))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u106))
(define-constant ERR-PLATFORM-INACTIVE (err u107))
(define-constant ERR-INVALID-NAME (err u108))
(define-constant ERR-PRODUCT-INACTIVE (err u109))
(define-constant ERR-INVALID-FEE (err u110))
(define-constant ERR-INVALID-DATE-RANGE (err u111))
(define-constant ERR-INVALID-STOCK (err u112))
(define-constant ERR-INVALID-CATEGORY (err u113))

;; Define data variables
(define-data-var platform-fee uint u25) ;; 0.25% fee
(define-data-var total-revenue uint u0)
(define-data-var total-transactions uint u0)
(define-data-var platform-active bool true)

;; Define data maps
(define-map products
    { product-id: uint }
    {
        name: (string-ascii 50),
        price: uint,
        stock: uint,
        category: (string-ascii 30),
        seller: principal,
        total-sold: uint,
        revenue: uint,
        created-at: uint,
        active: bool
    }
)

(define-map sales
    { sale-id: uint }
    {
        product-id: uint,
        buyer: principal,
        seller: principal,
        quantity: uint,
        total-amount: uint,
        timestamp: uint,
        payment-method: (string-ascii 20)
    }
)

(define-map customers
    { customer: principal }
    {
        total-purchases: uint,
        total-spent: uint,
        first-purchase: uint,
        last-purchase: uint,
        favorite-category: (string-ascii 30),
        loyalty-points: uint
    }
)

(define-map sellers
    { seller: principal }
    {
        total-products: uint,
        total-sales: uint,
        total-revenue: uint,
        rating: uint,
        joined-at: uint,
        active: bool
    }
)

(define-map category-analytics
    { category: (string-ascii 30) }
    {
        total-products: uint,
        total-sales: uint,
        total-revenue: uint,
        avg-price: uint
    }
)

(define-map authorized-analysts
    { analyst: principal }
    { authorized: bool }
)

;; Define sequence counters
(define-data-var next-product-id uint u1)
(define-data-var next-sale-id uint u1)

;; Input validation helper functions
(define-private (validate-stock (stock uint))
    (and (>= stock u0) (<= stock u1000000)) ;; Max stock limit for sanity
)

(define-private (validate-category (category (string-ascii 30)))
    (and (> (len category) u0) (<= (len category) u30))
)

(define-private (validate-product-id (product-id uint))
    (and (> product-id u0) (< product-id (var-get next-product-id)))
)

;; Read-only functions

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-revenue: (var-get total-revenue),
        total-transactions: (var-get total-transactions),
        platform-fee: (var-get platform-fee),
        active: (var-get platform-active)
    }
)

;; Get product details
(define-read-only (get-product (product-id uint))
    (map-get? products { product-id: product-id })
)

;; Get sale details
(define-read-only (get-sale (sale-id uint))
    (map-get? sales { sale-id: sale-id })
)

;; Get customer analytics
(define-read-only (get-customer-analytics (customer principal))
    (map-get? customers { customer: customer })
)

;; Get seller analytics
(define-read-only (get-seller-analytics (seller principal))
    (map-get? sellers { seller: seller })
)

;; Get category analytics
(define-read-only (get-category-analytics (category (string-ascii 30)))
    (map-get? category-analytics { category: category })
)

;; Calculate customer lifetime value
(define-read-only (get-customer-lifetime-value (customer principal))
    (match (map-get? customers { customer: customer })
        customer-data
        (let ((total-spent (get total-spent customer-data))
              (total-purchases (get total-purchases customer-data)))
            (if (> total-purchases u0)
                (/ total-spent total-purchases)
                u0))
        u0)
)

;; Get top selling products
(define-read-only (is-top-product (product-id uint) (min-sales uint))
    (match (map-get? products { product-id: product-id })
        product-data
        (>= (get total-sold product-data) min-sales)
        false)
)

;; Check if user is authorized analyst
(define-read-only (is-authorized-analyst (analyst principal))
    (default-to false (get authorized (map-get? authorized-analysts { analyst: analyst })))
)

;; Public functions

;; Add a new product
(define-public (add-product (name (string-ascii 50)) (price uint) (stock uint) (category (string-ascii 30)))
    (let ((product-id (var-get next-product-id))
          (seller tx-sender))
        (asserts! (var-get platform-active) ERR-PLATFORM-INACTIVE)
        (asserts! (> price u0) ERR-INVALID-PRICE)
        (asserts! (> (len name) u0) ERR-INVALID-NAME)
        (asserts! (validate-stock stock) ERR-INVALID-STOCK)
        (asserts! (validate-category category) ERR-INVALID-CATEGORY)
        
        ;; Add product with validated inputs
        (map-set products
            { product-id: product-id }
            {
                name: name,
                price: price,
                stock: stock,
                category: category,
                seller: seller,
                total-sold: u0,
                revenue: u0,
                created-at: block-height,
                active: true
            }
        )
        
        ;; Update seller stats
        (update-seller-stats seller u1 u0 u0)
        
        ;; Update category stats with validated category
        (update-category-stats category u1 u0 u0 price)
        
        ;; Increment product counter
        (var-set next-product-id (+ product-id u1))
        
        (ok product-id))
)

;; Purchase a product
(define-public (purchase-product (product-id uint) (quantity uint))
    (let ((buyer tx-sender)
          (sale-id (var-get next-sale-id)))
        (asserts! (var-get platform-active) ERR-PLATFORM-INACTIVE)
        (asserts! (> quantity u0) ERR-INVALID-AMOUNT)
        (asserts! (validate-product-id product-id) ERR-NOT-FOUND)
        
        (match (map-get? products { product-id: product-id })
            product-data
            (let ((seller (get seller product-data))
                  (price (get price product-data))
                  (available-stock (get stock product-data))
                  (total-amount (* price quantity))
                  (platform-fee-amount (/ (* total-amount (var-get platform-fee)) u10000)))
                
                (asserts! (get active product-data) ERR-PRODUCT-INACTIVE)
                (asserts! (>= available-stock quantity) ERR-INSUFFICIENT-STOCK)
                
                ;; Update product stock and sales
                (map-set products
                    { product-id: product-id }
                    (merge product-data {
                        stock: (- available-stock quantity),
                        total-sold: (+ (get total-sold product-data) quantity),
                        revenue: (+ (get revenue product-data) total-amount)
                    })
                )
                
                ;; Record sale
                (map-set sales
                    { sale-id: sale-id }
                    {
                        product-id: product-id,
                        buyer: buyer,
                        seller: seller,
                        quantity: quantity,
                        total-amount: total-amount,
                        timestamp: block-height,
                        payment-method: "STX"
                    }
                )
                
                ;; Update customer analytics
                (update-customer-analytics buyer total-amount (get category product-data))
                
                ;; Update seller analytics
                (update-seller-stats seller u0 quantity total-amount)
                
                ;; Update category analytics
                (update-category-stats (get category product-data) u0 quantity total-amount price)
                
                ;; Update platform stats
                (var-set total-revenue (+ (var-get total-revenue) total-amount))
                (var-set total-transactions (+ (var-get total-transactions) u1))
                (var-set next-sale-id (+ sale-id u1))
                
                (ok sale-id))
            ERR-NOT-FOUND))
)

;; Update product details (seller only)
(define-public (update-product (product-id uint) (price uint) (stock uint))
    (begin
        (asserts! (validate-product-id product-id) ERR-NOT-FOUND)
        (asserts! (> price u0) ERR-INVALID-PRICE)
        (asserts! (validate-stock stock) ERR-INVALID-STOCK)
        
        (match (map-get? products { product-id: product-id })
            product-data
            (begin
                (asserts! (is-eq tx-sender (get seller product-data)) ERR-UNAUTHORIZED-ACCESS)
                
                (map-set products
                    { product-id: product-id }
                    (merge product-data {
                        price: price,
                        stock: (+ (get stock product-data) stock)
                    })
                )
                (ok true))
            ERR-NOT-FOUND))
)

;; Deactivate product (seller only)
(define-public (deactivate-product (product-id uint))
    (begin
        (asserts! (validate-product-id product-id) ERR-NOT-FOUND)
        
        (match (map-get? products { product-id: product-id })
            product-data
            (begin
                (asserts! (is-eq tx-sender (get seller product-data)) ERR-UNAUTHORIZED-ACCESS)
                
                (map-set products
                    { product-id: product-id }
                    (merge product-data { active: false })
                )
                (ok true))
            ERR-NOT-FOUND))
)

;; Admin functions

;; Set platform fee (owner only)
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
        (asserts! (<= new-fee u1000) ERR-INVALID-FEE) ;; Max 10%
        (var-set platform-fee new-fee)
        (ok true))
)

;; Toggle platform status (owner only)
(define-public (toggle-platform-status)
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
        (var-set platform-active (not (var-get platform-active)))
        (ok (var-get platform-active)))
)

;; Authorize analyst (owner only)
(define-public (authorize-analyst (analyst principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
        ;; Additional check to prevent self-authorization loops
        (asserts! (not (is-eq analyst contract-owner)) ERR-UNAUTHORIZED-ACCESS)
        (map-set authorized-analysts { analyst: analyst } { authorized: true })
        (ok true))
)

;; Revoke analyst authorization (owner only)
(define-public (revoke-analyst (analyst principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
        (asserts! (not (is-eq analyst contract-owner)) ERR-UNAUTHORIZED-ACCESS)
        (map-set authorized-analysts { analyst: analyst } { authorized: false })
        (ok true))
)

;; Private functions

;; Update customer analytics
(define-private (update-customer-analytics (customer principal) (amount uint) (category (string-ascii 30)))
    (let ((current-data (default-to
            {
                total-purchases: u0,
                total-spent: u0,
                first-purchase: block-height,
                last-purchase: u0,
                favorite-category: category,
                loyalty-points: u0
            }
            (map-get? customers { customer: customer }))))
        
        (map-set customers
            { customer: customer }
            {
                total-purchases: (+ (get total-purchases current-data) u1),
                total-spent: (+ (get total-spent current-data) amount),
                first-purchase: (if (is-eq (get total-purchases current-data) u0) 
                                   block-height 
                                   (get first-purchase current-data)),
                last-purchase: block-height,
                favorite-category: category,
                loyalty-points: (+ (get loyalty-points current-data) (/ amount u100))
            }
        )
    )
)

;; Update seller analytics
(define-private (update-seller-stats (seller principal) (products-added uint) (items-sold uint) (revenue uint))
    (let ((current-data (default-to
            {
                total-products: u0,
                total-sales: u0,
                total-revenue: u0,
                rating: u5,
                joined-at: block-height,
                active: true
            }
            (map-get? sellers { seller: seller }))))
        
        (map-set sellers
            { seller: seller }
            {
                total-products: (+ (get total-products current-data) products-added),
                total-sales: (+ (get total-sales current-data) items-sold),
                total-revenue: (+ (get total-revenue current-data) revenue),
                rating: (get rating current-data),
                joined-at: (if (is-eq (get total-products current-data) u0) 
                              block-height 
                              (get joined-at current-data)),
                active: true
            }
        )
    )
)

;; Update category analytics
(define-private (update-category-stats (category (string-ascii 30)) (products-added uint) (items-sold uint) (revenue uint) (price uint))
    (let ((current-data (default-to
            {
                total-products: u0,
                total-sales: u0,
                total-revenue: u0,
                avg-price: u0
            }
            (map-get? category-analytics { category: category }))))
        
        (let ((new-total-products (+ (get total-products current-data) products-added))
              (new-total-revenue (+ (get total-revenue current-data) revenue)))
            
            (map-set category-analytics
                { category: category }
                {
                    total-products: new-total-products,
                    total-sales: (+ (get total-sales current-data) items-sold),
                    total-revenue: new-total-revenue,
                    avg-price: (if (> new-total-products u0)
                                  (/ new-total-revenue new-total-products)
                                  u0)
                }
            )
        )
    )
)

;; Analytics query functions (authorized analysts only)

;; Get sales report for date range
(define-public (get-sales-report (start-block uint) (end-block uint))
    (begin
        (asserts! (or (is-eq tx-sender contract-owner) (is-authorized-analyst tx-sender)) ERR-UNAUTHORIZED-ACCESS)
        (asserts! (<= start-block end-block) ERR-INVALID-DATE-RANGE)
        (ok (get-platform-stats)))
)

;; Generate customer insights
(define-public (generate-customer-insights (customer principal))
    (begin
        (asserts! (or (is-eq tx-sender contract-owner) (is-authorized-analyst tx-sender)) ERR-UNAUTHORIZED-ACCESS)
        (match (map-get? customers { customer: customer })
            customer-data
            (ok {
                customer: customer,
                lifetime-value: (get-customer-lifetime-value customer),
                analytics: customer-data
            })
            ERR-NOT-FOUND))
)