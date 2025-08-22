# Retail Analytics Platform Smart Contract

A comprehensive smart contract platform for tracking retail sales, managing products, and generating customer analytics on the Stacks blockchain.

## Overview

This smart contract provides a complete retail ecosystem that allows sellers to list products, customers to make purchases, and administrators to analyze sales data. The platform includes built-in analytics, fee management, and access control systems.

## Features

### Core Functionality
- **Product Management**: Add, update, and deactivate products
- **Sales Processing**: Handle customer purchases with automatic stock management
- **Customer Analytics**: Track customer behavior, spending patterns, and loyalty points
- **Seller Analytics**: Monitor seller performance and revenue
- **Category Analytics**: Analyze sales performance by product category

### Analytics & Insights
- Platform-wide statistics and revenue tracking
- Customer lifetime value calculations
- Top-selling product identification
- Sales reporting with date range filtering
- Comprehensive customer and seller insights

### Administrative Features
- Platform fee configuration (up to 10%)
- Platform activation/deactivation controls
- Analyst authorization management
- Owner-only administrative functions

## Contract Structure

### Data Maps

#### Products Map
Stores product information including:
- Name, price, stock quantity
- Category and seller information
- Sales metrics and revenue tracking
- Creation timestamp and active status

#### Sales Map
Records all transactions with:
- Product and participant details
- Quantity and total amount
- Timestamp and payment method
- Unique sale identification

#### Customers Map
Tracks customer analytics:
- Purchase history and spending totals
- First and last purchase timestamps
- Favorite category preferences
- Loyalty points accumulation

#### Sellers Map
Maintains seller statistics:
- Product count and sales volume
- Total revenue and ratings
- Join date and active status

#### Category Analytics Map
Aggregates category-level data:
- Product count and sales volume
- Revenue totals and average pricing

### Access Control
- **Contract Owner**: Full administrative privileges
- **Authorized Analysts**: Access to analytics and reporting functions
- **Sellers**: Can manage their own products
- **Customers**: Can purchase products and view their own data

## Public Functions

### Product Management

#### `add-product`
```clarity
(add-product (name (string-ascii 50)) (price uint) (stock uint) (category (string-ascii 30)))
```
Adds a new product to the platform. Returns the assigned product ID.

**Requirements:**
- Platform must be active
- Price must be greater than 0
- Name must not be empty

#### `update-product`
```clarity
(update-product (product-id uint) (price uint) (stock uint))
```
Updates product price and adds to stock quantity. Only callable by the product seller.

#### `deactivate-product`
```clarity
(deactivate-product (product-id uint))
```
Deactivates a product, preventing further sales. Only callable by the product seller.

### Sales Operations

#### `purchase-product`
```clarity
(purchase-product (product-id uint) (quantity uint))
```
Processes a product purchase, updating all relevant analytics and stock levels.

**Requirements:**
- Platform must be active
- Quantity must be greater than 0
- Product must be active
- Sufficient stock must be available

### Administrative Functions

#### `set-platform-fee`
```clarity
(set-platform-fee (new-fee uint))
```
Sets the platform transaction fee (maximum 10%). Owner only.

#### `toggle-platform-status`
```clarity
(toggle-platform-status)
```
Activates or deactivates the entire platform. Owner only.

#### `authorize-analyst` / `revoke-analyst`
```clarity
(authorize-analyst (analyst principal))
(revoke-analyst (analyst principal))
```
Manages analyst access permissions. Owner only.

### Analytics Functions

#### `get-sales-report`
```clarity
(get-sales-report (start-block uint) (end-block uint))
```
Generates sales reports for specified block range. Requires analyst authorization.

#### `generate-customer-insights`
```clarity
(generate-customer-insights (customer principal))
```
Provides detailed customer analytics including lifetime value. Requires analyst authorization.

## Read-Only Functions

### Data Retrieval
- `get-platform-stats`: Platform-wide statistics
- `get-product`: Product details by ID
- `get-sale`: Sale details by ID
- `get-customer-analytics`: Customer data and metrics
- `get-seller-analytics`: Seller performance data
- `get-category-analytics`: Category-level insights

### Utility Functions
- `get-customer-lifetime-value`: Calculate customer lifetime value
- `is-top-product`: Check if product meets sales threshold
- `is-authorized-analyst`: Verify analyst permissions

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR-OWNER-ONLY | Function restricted to contract owner |
| u101 | ERR-NOT-FOUND | Requested resource not found |
| u102 | ERR-ALREADY-EXISTS | Resource already exists |
| u103 | ERR-INVALID-AMOUNT | Invalid quantity specified |
| u104 | ERR-INVALID-PRICE | Invalid price specified |
| u105 | ERR-INSUFFICIENT-STOCK | Not enough stock available |
| u106 | ERR-UNAUTHORIZED-ACCESS | Access denied for operation |
| u107 | ERR-PLATFORM-INACTIVE | Platform is currently inactive |
| u108 | ERR-INVALID-NAME | Invalid product name |
| u109 | ERR-PRODUCT-INACTIVE | Product is deactivated |
| u110 | ERR-INVALID-FEE | Invalid fee amount |
| u111 | ERR-INVALID-DATE-RANGE | Invalid date range specified |

## Usage Examples

### Adding a Product
```clarity
(contract-call? .retail-analytics add-product "Wireless Headphones" u15000 u50 "Electronics")
```

### Making a Purchase
```clarity
(contract-call? .retail-analytics purchase-product u1 u2)
```

### Checking Platform Statistics
```clarity
(contract-call? .retail-analytics get-platform-stats)
```

### Analyzing Customer Data
```clarity
(contract-call? .retail-analytics get-customer-analytics 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
```

## Platform Economics

### Fee Structure
- Default platform fee: 0.25%
- Maximum allowable fee: 10%
- Fees calculated on total transaction amount

### Loyalty System
- Customers earn 1 loyalty point per 100 units spent
- Points accumulate automatically with each purchase

### Revenue Tracking
- All transactions contribute to platform revenue totals
- Individual seller revenue tracked separately
- Category-level revenue aggregation available

## Security Features

- Owner-only administrative functions
- Seller-only product management
- Analyst authorization system
- Input validation on all parameters
- Stock management prevents overselling
- Platform-wide activation controls

## Deployment Notes

- Contract owner is set to the deploying address
- Platform starts in active state
- Initial product and sale IDs begin at 1
- No products or sales exist at deployment