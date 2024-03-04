// Start - Support direct Mocha run & debug
import 'hardhat'
import '@nomiclabs/hardhat-ethers'
// End - Support direct Mocha run & debug

import chai, {expect} from 'chai'
import {before} from 'mocha'
import {solidity} from 'ethereum-waffle'
import {deployContract, signer} from './framework/contracts'
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers'
import {successfulTransaction} from './framework/transaction'
import {DeBay} from '../typechain-types'
import {ethers} from 'ethers'

chai.use(solidity)

describe('DeBay test suite', () => {
    let contract: DeBay
    let s0: SignerWithAddress, s1: SignerWithAddress, s2: SignerWithAddress

    before(async () => {
        s0 = await signer(0)
        s1 = await signer(1)
        s2 = await signer(2)
    })
    beforeEach(async () => {
        contract = await deployContract<DeBay>('DeBay')
    })
    describe('Normal Bidding Process', () => {
        it('should complete a normal bidding process', async () => {
            const name = 'Kanye West Doll'
            const imgUrl = 'weirdkayne.com'
            const description = 'Trying to get rid of it'
            const floor = 5
            const deadline = 1000
            const auctionId = await contract.getAuctionId(
                s0.address,
                deadline,
                name,
                imgUrl,
                description
            )
            const currentBidder = 0x0000000000000000000000000000000000000000
            const auctionBalance = 0
            const currentBid = 0

            const tx0 = await contract
                .connect(s0)
                .startAuction(name, imgUrl, description, floor, deadline)
            let auction = await contract.getAuction(auctionId)
            expect(auction.auctionStatus).to.be.true
            expect(auction.name).to.equal(name)
            expect(auction.initiator).to.equal(s0.address)
            expect(auction.imgUrl).to.equal(imgUrl)
            expect(auction.description).to.equal(description)
            expect(auction.floor).to.equal(floor)
            await expect(tx0).to.emit(contract, 'AuctionStarted')

            const tx1 = await contract.connect(s1)['bid(bytes32)'](auctionId, {
                value: ethers.utils.parseEther('7')
            })
            auction = await contract.getAuction(auctionId)
            expect(auction.currentBidder).to.equal(s1.address)
            await expect(tx1).to.emit(contract, 'Bid')
            await contract
                .connect(s2)
                .deposit({value: ethers.utils.parseEther('20')})

            const tx2 = await contract
                .connect(s2)
                ['bid(bytes32,uint256)'](
                    auctionId,
                    ethers.utils.parseEther('8')
                )
            auction = await contract.getAuction(auctionId)
            expect(auction.currentBidder).to.equal(s2.address)
            await expect(tx2).to.emit(contract, 'Bid')
        })
    })
    describe('Actions that should not be allowed', () => {
        it('should stop the same user from creating identical campaigns', async () => {
            const name = 'Kanye West Doll'
            const imgUrl = 'weirdkayne.com'
            const description = 'Trying to get rid of it'
            const floor = 5
            const deadline = 5
            const auctionId = await contract.getAuctionId(
                s0.address,
                deadline,
                name,
                imgUrl,
                description
            )
            await contract
                .connect(s0)
                .startAuction(name, imgUrl, description, floor, deadline)
            await expect(
                contract
                    .connect(s0)
                    .startAuction(name, imgUrl, description, floor, deadline)
            ).to.be.revertedWith('Auction exists')
        })
        it('should only allow initiator to end campaign', async () => {
            const name = 'Kanye West Doll'
            const imgUrl = 'weirdkayne.com'
            const description = 'Trying to get rid of it'
            const floor = 5
            const deadline = 5
            const auctionId = await contract.getAuctionId(
                s0.address,
                deadline,
                name,
                imgUrl,
                description
            )
            await contract
                .connect(s0)
                .startAuction(name, imgUrl, description, floor, deadline)
            const campaignId = await contract.getAuctionId(
                s0.address,
                deadline,
                name,
                imgUrl,
                description
            )
            await expect(
                contract.connect(s1).settle(auctionId)
            ).to.be.revertedWith('Not Auction Owner')
        })
    })
})
