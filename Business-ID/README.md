# Global LEI Registry Smart Contract

A focused blockchain registry for Legal Entity Identifiers (LEI) that balances essential on-chain functionality with gas efficiency. This smart contract handles critical operations that require immutability and consensus while keeping costs reasonable.

## Overview

The Global LEI Registry provides essential blockchain-based management for Legal Entity Identifiers, focusing on core functionality needed for regulatory compliance and ownership tracking.

### Key Features

- **LEI Registration**: Register new LEIs with ownership and metadata
- **Multi-Status Lifecycle**: Manage LEIs through ACTIVE, SUSPENDED, EXPIRED, and RETIRED states
- **Ownership Transfers**: Secure transfer of LEI ownership with event logging
- **Expiration Tracking**: Automated compliance tracking for regulatory requirements
- **Portfolio Management**: Track all LEIs owned by each entity
- **Role-Based Access**: Administrative controls with multiple permission levels
- **Data Validation**: Comprehensive validation for data integrity

## Contract Architecture

### Core Data Structures

#### LEI Registry
```clarity
(define-map lei-registry
  { lei: (string-ascii 20) }
  {
    owner: principal,
    status: (string-ascii 12),
    registered-at: uint,
    expires-at: uint,
    last-updated: uint
  }
)
```

#### Owner Portfolios
```clarity
(define-map owner-portfolios
  { owner: principal }
  { lei-count: uint, leis: (list 50 (string-ascii 20)) }
)
```

#### Admin Roles
```clarity
(define-map admins
  { admin: principal }
  { authorized: bool, role: (string-ascii 10) }
)
```

## Functions

### Administrative Functions

#### `transfer-ownership`
```clarity
(define-public (transfer-ownership (new-owner principal)))
```
Transfer contract ownership to a new address. Only current owner can execute.

#### `add-admin`
```clarity
(define-public (add-admin (admin-address principal) (admin-role (string-ascii 10))))
```
Add a new administrator with SUPER or BASIC role. Only contract owner can execute.

#### `remove-admin`
```clarity
(define-public (remove-admin (admin-address principal)))
```
Remove administrator privileges. Only contract owner can execute.

### Core LEI Management

#### `register-lei`
```clarity
(define-public (register-lei 
  (lei (string-ascii 20)) 
  (lei-owner principal) 
  (expiration-height uint)))
```
Register a new LEI with specified owner and expiration. Only admins can execute.

**Parameters:**
- `lei`: 20-character ASCII string LEI identifier
- `lei-owner`: Principal address of the LEI owner
- `expiration-height`: Block height when LEI expires

#### `transfer-lei`
```clarity
(define-public (transfer-lei (lei (string-ascii 20)) (new-owner principal)))
```
Transfer LEI ownership to a new address. Can be executed by current owner or admin.

#### `update-lei-status`
```clarity
(define-public (update-lei-status (lei (string-ascii 20)) (new-status (string-ascii 12))))
```
Update LEI status. Only admins can execute.

**Valid Status Values:**
- `ACTIVE`: LEI is operational
- `SUSPENDED`: Temporarily inactive
- `EXPIRED`: Past expiration date
- `RETIRED`: Permanently deactivated

#### `extend-lei-expiration`
```clarity
(define-public (extend-lei-expiration (lei (string-ascii 20)) (new-expiration uint)))
```
Extend LEI expiration date and reactivate if expired. Only admins can execute.

#### `batch-expire-leis`
```clarity
(define-public (batch-expire-leis (lei-list (list 20 (string-ascii 20)))))
```
Batch update multiple LEIs to expired status. Only super admins can execute.

### Read-Only Functions

#### `get-lei-details`
```clarity
(define-read-only (get-lei-details (lei (string-ascii 20))))
```
Retrieve complete LEI information including owner, status, and timestamps.

#### `is-lei-valid`
```clarity
(define-read-only (is-lei-valid (lei (string-ascii 20))))
```
Check if LEI is currently active and not expired.

#### `get-owner-portfolio`
```clarity
(define-read-only (get-owner-portfolio (owner principal)))
```
Retrieve all LEIs owned by a specific address.

#### `get-contract-stats`
```clarity
(define-read-only (get-contract-stats))
```
Get contract statistics including total registrations and current block height.

#### `get-admin-info`
```clarity
(define-read-only (get-admin-info (address principal)))
```
Check administrative status and role of an address.

#### `validate-lei-format`
```clarity
(define-read-only (validate-lei-format (lei (string-ascii 20))))
```
Validate LEI format (must be exactly 20 ASCII characters).

## Error Codes

### Access Control Errors
- `ERR-UNAUTHORIZED-ACCESS (100)`: Insufficient permissions
- `ERR-NOT-OWNER (101)`: Not the owner of the LEI
- `ERR-NOT-ADMIN (102)`: Admin privileges required
- `ERR-INVALID-ADMIN (103)`: Invalid admin role specified

### Validation Errors
- `ERR-INVALID-LEI-FORMAT (200)`: LEI format is incorrect
- `ERR-INVALID-STATUS (201)`: Invalid status value
- `ERR-INVALID-EXPIRATION (202)`: Invalid expiration date
- `ERR-INVALID-ADDRESS (203)`: Invalid principal address

### Business Logic Errors
- `ERR-LEI-EXISTS (300)`: LEI already registered
- `ERR-LEI-NOT-FOUND (301)`: LEI does not exist
- `ERR-LEI-EXPIRED (302)`: LEI has expired
- `ERR-SAME-OWNER (303)`: Transfer to same owner attempted

## Events

The contract emits events for off-chain indexing:

### `lei-registered`
```json
{
  "event": "lei-registered",
  "lei": "string",
  "owner": "principal",
  "block": "uint"
}
```

### `lei-transferred`
```json
{
  "event": "lei-transferred",
  "lei": "string",
  "from": "principal",
  "to": "principal",
  "block": "uint"
}
```

### `status-updated`
```json
{
  "event": "status-updated",
  "lei": "string",
  "status": "string",
  "block": "uint"
}
```

### `expiration-extended`
```json
{
  "event": "expiration-extended",
  "lei": "string",
  "expires-at": "uint",
  "block": "uint"
}
```

## Deployment and Initialization

Upon deployment, the contract automatically:
1. Sets the deployer as the contract owner
2. Grants the deployer SUPER admin privileges
3. Initializes total registrations counter to 0

## Usage Examples

### Register a New LEI
```clarity
;; Admin registers LEI for entity
(contract-call? .lei-registry register-lei
  "12345678901234567890"  ;; LEI
  'SP1ABC...               ;; Owner address
  u1000000)               ;; Expiration block
```

### Transfer LEI Ownership
```clarity
;; Owner transfers LEI to new address
(contract-call? .lei-registry transfer-lei
  "12345678901234567890"  ;; LEI
  'SP2DEF...)             ;; New owner
```

### Check LEI Status
```clarity
;; Check if LEI is valid
(contract-call? .lei-registry is-lei-valid
  "12345678901234567890")
```

### View Owner Portfolio
```clarity
;; Get all LEIs owned by address
(contract-call? .lei-registry get-owner-portfolio
  'SP1ABC...)
```

## Security Considerations

- **Access Control**: Multi-level permissions with owner, super admin, and basic admin roles
- **Input Validation**: All inputs are validated before processing
- **State Consistency**: Portfolio tracking is automatically maintained
- **Event Logging**: All state changes emit events for auditability
- **Gas Efficiency**: Focused functionality to minimize transaction costs

## Limitations

- Maximum 50 LEIs per owner portfolio
- Maximum 20 LEIs per batch expiration operation
- LEI identifiers must be exactly 20 ASCII characters
- Status values are limited to predefined options