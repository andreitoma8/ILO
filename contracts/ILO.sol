// SPDX-License-Identifier: MIT
// Creator: andreitoma8
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ILO is Ownable {
    IERC20 token;

    bool public iloFulfilled = false;

    bool public iloSuccess;

    uint256 public tokensSold;

    uint256 public fundsRaised;

    uint256 public immutable minBuy;

    uint256 internal immutable totalSaleSupply;

    uint256 internal constant minBougth = 50;

    uint256 internal immutable whitelistSaleStart;

    uint256 internal immutable mainSaleStart;

    uint256 internal immutable mainSaleEnd;

    uint256 public immutable pricePerToken;

    uint256 public immutable pricePerTokenPresale;

    bytes32 internal immutable merkleRoot;

    mapping(address => uint256) tokenBougth;

    mapping(address => uint256) valuePaid;

    event TokenBougth(address indexed buyer, uint256 indexed amountBougth);

    event Withdrawal(address indexed buyer, uint256 indexed amountWithdrawn);

    constructor(
        address _token,
        uint256 _whitelistSaleStart,
        uint256 _pricePerToken,
        uint256 _pricePerTokenPresale,
        uint256 _tokenAmountToSale,
        uint256 _minBuy,
        bytes32 _merkleRoot
    ) {
        token = IERC20(_token);
        whitelistSaleStart = _whitelistSaleStart;
        mainSaleStart = whitelistSaleStart + 86400;
        mainSaleEnd = whitelistSaleStart + 172800;
        pricePerToken = _pricePerToken;
        pricePerTokenPresale = _pricePerTokenPresale;
        token.transferFrom(msg.sender, address(this), _tokenAmountToSale);
        totalSaleSupply = _tokenAmountToSale;
        minBuy = _minBuy;
        merkleRoot = _merkleRoot;
    }

    function whitelistSaleBuy(bytes32[] calldata _merkleProof) public payable {
        require(
            block.timestamp > whitelistSaleStart &&
                block.timestamp < mainSaleStart,
            "Whitelist Sale not active"
        );
        require(
            msg.value > minBuy,
            "Your transaction value is below minimum buy"
        );
        bytes32 leaf = keccak256(abi.encodePacked((msg.sender)));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid proof"
        );
        valuePaid[msg.sender] += msg.value;
        tokenBougth[msg.sender] += msg.value / pricePerTokenPresale;
        tokensSold += msg.value / pricePerTokenPresale;
        fundsRaised += msg.value;
        emit TokenBougth(msg.sender, msg.value / pricePerTokenPresale);
    }

    function mainBuy() public payable {
        require(
            block.timestamp > mainSaleStart && block.timestamp < mainSaleEnd,
            "Whitelist Sale didn't start yet"
        );
        require(
            msg.value > minBuy,
            "Your transaction value is below minimum buy"
        );
        valuePaid[msg.sender] += msg.value;
        tokenBougth[msg.sender] += msg.value / pricePerToken;
        tokensSold += msg.value / pricePerToken;
        fundsRaised += msg.value;
        emit TokenBougth(msg.sender, msg.value / pricePerToken);
    }

    function fulfillILO() public {
        require(block.timestamp > mainSaleEnd, "Sale still active");
        require(!iloFulfilled, "ILO already Fulfilled");
        if ((tokensSold * 50) / 100 > totalSaleSupply) {
            depositLiquidity();
        }
        iloFulfilled = true;
    }

    function withdrawPublic() public {
        require(block.timestamp > mainSaleEnd, "Sale still active");
        if (iloFulfilled) {
            uint256 _tokenAmountToSend = tokenBougth[msg.sender];
            tokenBougth[msg.sender] = 0;
            valuePaid[msg.sender] = 0;
            token.transfer(msg.sender, _tokenAmountToSend);
            emit Withdrawal(msg.sender, _tokenAmountToSend);
        } else {
            uint256 _amountToSend = valuePaid[msg.sender];
            tokenBougth[msg.sender] = 0;
            valuePaid[msg.sender] = 0;
            (bool os, ) = payable(msg.sender).call{value: _amountToSend}("");
            require(os);
            emit Withdrawal(msg.sender, _amountToSend);
        }
    }

    function depositLiquidity() internal {}

    function withdrawOwner() public onlyOwner {
        require(iloFulfilled, "ILO is not over");
        if (iloSuccess) {
            (bool os, ) = payable(owner()).call{value: address(this).balance}(
                ""
            );
            require(os);
        }
    }
}
