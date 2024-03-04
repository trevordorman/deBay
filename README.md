# deBay
deBay is an auction platform, eBay but decentralized. The features include:
- Anyone can start an auction and anyone else can bid.
- Every new bid must be higher than the current bid.
- The initiator cannot bid on their own auctions.
- Bidders who are outbid can retrieve their funds.
    - Bidders also have the option of leaving these funds in the contract, depositing more funds, then submitting a higher bid for the same item.
    - Bidders can also recycle their funds to be used to bid on other items, without their funds leaving the contract.
- Every bid has a deadline, which is a timestamp.
- Nobody can bid past the deadline. However, anyone can settle a bid past the deadline (announcing the bid winner).
- Nobody can start an auction, bid, settle, deposit more funds, or withdraw funds when the contract is paused.
