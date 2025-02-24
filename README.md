# TicketChain

## Decentralized Event Ticketing with Risk Protection

TicketChain is a blockchain-based ticketing solution that leverages the security and transparency of Stacks blockchain and Clarity smart contracts to revolutionize how event tickets are issued, transferred, and validated.

![TicketChain Logo](https://placeholder-image.com/ticketchain-logo.png)

## Features

- **Decentralized Ticket Issuance**: Event organizers can create events and issue NFT-based tickets without intermediaries
- **Risk Protection**: Ticket buyers can opt for built-in risk protection for a small fee (5% of ticket price)
- **Transfer Restrictions**: One-time transfer limit to reduce scalping and unauthorized reselling
- **Event Cancellation Protection**: Automatic refund mechanism for cancelled events
- **Verifiable Attendance**: Event organizers can verify ticket validity at entry

## Smart Contract Overview

The TicketChain smart contract is built on Clarity, the smart contract language for the Stacks blockchain. Key components include:

- **Events Management**: Create, manage, and cancel events
- **Ticket Operations**: Purchase, transfer, and validate tickets
- **Risk Protection System**: Optional insurance mechanism for ticket buyers
- **Refund Processing**: Automated refunds for cancelled events

## Getting Started

### Prerequisites

- [Stacks Wallet](https://www.hiro.so/wallet)
- [Clarinet](https://github.com/hirosystems/clarinet) for local development and testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ticketchain.git
cd ticketchain
```

2. Install dependencies:
```bash
npm install
```

3. Setup local Clarinet environment:
```bash
clarinet integrate
```

## Usage

### For Event Organizers

#### Creating an Event
```clarity
(contract-call? .ticketchain create-event "Concert Name" u500 u50000 u10000 "Venue Details")
```
Parameters:
- Event name (string-ascii, max 100 chars)
- Maximum attendees (uint)
- Ticket price in microSTX (uint)
- Event time as block height (uint)
- Location information (string-ascii, max 256 chars)

#### Cancelling an Event
```clarity
(contract-call? .ticketchain cancel-event u1)
```

#### Verifying a Ticket
```clarity
(contract-call? .ticketchain verify-ticket u5)
```

### For Ticket Buyers

#### Purchasing a Ticket
```clarity
;; Without risk protection
(contract-call? .ticketchain buy-ticket u1 false)

;; With risk protection
(contract-call? .ticketchain buy-ticket u1 true)
```

#### Transferring a Ticket
```clarity
(contract-call? .ticketchain transfer-ticket u5 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### Claiming a Refund for Cancelled Event
```clarity
(contract-call? .ticketchain get-refund u5)
```

#### Using Risk Protection
```clarity
(contract-call? .ticketchain use-protection u5)
```

## Technical Details

### Data Structures

The contract uses three main data maps:
1. **Events**: Stores event details
2. **Tickets**: Stores individual ticket information
3. **EventTickets**: Maps events to their associated tickets

### Error Codes

- `ERR-NOT-ALLOWED (u100)`: Unauthorized access
- `ERR-EVENT-NOT-FOUND (u101)`: Event or ticket not found
- `ERR-SOLD-OUT (u102)`: No more tickets available
- `ERR-TRANSFER-BLOCKED (u103)`: Ticket already transferred once
- `ERR-EVENT-ACTIVE (u104)`: Event still active
- `ERR-REFUND-DENIED (u105)`: Refund conditions not met
- `ERR-PROTECTION-USED (u106)`: Risk protection already claimed
- `ERR-INVALID-INPUT (u107)`: Invalid parameter values

## Security Considerations

- The contract implements access controls to ensure only authorized users can perform sensitive operations
- Risk protection funds are held in a separate vault address
- Ticket transfers are limited to once per ticket to prevent unlimited reselling

## Development and Testing

Run tests using Clarinet:

```bash
clarinet test
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request


