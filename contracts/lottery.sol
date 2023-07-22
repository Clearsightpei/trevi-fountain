// SPDX-License-Identifier: MIT
// An example of a consumer contract that directly pays for each request.
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

contract VRFv2DirectFundingConsumer is
    VRFV2WrapperConsumerBase,
    ConfirmedOwner
{
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomW,
        uint256 payment
    );

    struct Status {
        uint256 pay;
        bool fulfill;
        uint256[] randomW;
    }
    mapping(uint256 => Status)
        public s_requests;


    uint256[] public requestIds;
    uint256 public lastRequestId;


    uint32 callbackGasLimit = 10;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    address linkAd = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address wrapperAd = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

    constructor()
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(linkAd, wrapperAd)
    {}

    function requestRandomWords()
        external
        onlyOwner
        returns (uint256 requestId)
    {
        requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        s_requests[requestId] = Status({
            pay: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomW: new uint256[](0),
            fulfill: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].pay > 0, "request not found");
        s_requests[_requestId].fulfill = true;
        s_requests[_requestId].randomW = _randomWords;
        emit RequestFulfilled(
            _requestId,
            _randomWords,
            s_requests[_requestId].pay
        );
    }

    function getRequestStatus(
        uint256 _requestId
    )
        external
        view
        returns (uint256 paid, bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].pay > 0, "request not found");
        Status memory request = s_requests[_requestId];
        return (request.pay, request.fulfill, request.randomW);
    }
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAd);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
     address public manager;
    address public winner;
    address[] public players;

    function Lottery() public{
        manager = msg.sender;
    }

    function enter() public payable restricted{
        players.push(msg.sender);
    }

    modifier restricted {
        require(msg.value > .01 ether );
        _;
    }
    function getAllPlayers() public view returns (address[] memory){
        return players;
    }

    function pickWinner() public {
    require(manager == msg.sender);

    require(requestIds.length > 0, "No fulfilled requests yet");

    uint256 latestRequestId = requestIds[requestIds.length - 1];
    uint256[] memory randomWords = s_requests[latestRequestId].randomW;

    // Ensure that the randomWords array contains at least one element
    require(randomWords.length > 0, "Random words not available");

    // Use the first random word as the index to pick the winner
    uint index = randomWords[0] % players.length;
    winner = players[index];

    // Convert the winner address to "address payable"
    address payable winnerPayable = payable(winner);

    // Transfer the winnings to the winner
    winnerPayable.transfer(address(this).balance / 5);

    // Reset players array for the next round
    players = new address[](0);
}


    function getWinner() public view returns (address){
        return winner;
    }

    function getPoolBalance() public view returns (uint){
        return address(this).balance;
    }
}