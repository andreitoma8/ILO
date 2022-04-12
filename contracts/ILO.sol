// SPDX-License-Identifier: MIT
// Creator: andreitoma8
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ILO {
    IERC20 token;

    bool public iloFulfilled = false;

    uint256 internal immutable totalSaleSupply;

    uint256 internal constant minBougth = 50;

    uint256 internal immutable whitelistSaleStart;

    uint256 internal immutable mainSaleStart;

    uint256 internal immutable mainSaleEnd;

    uint256 public immutable pricePerToken;

    uint256 public immutable pricePerTokenPresale;

    mapping(address => uint256) tokenBougth;

    mapping(address => uint256) valuePaid;

    event TokenBougth(address indexed buyer, uint256 indexed amountBougth);

    event Withdrawal(address indexed buyer, uint256 indexed amountWithdrawn);

    constructor(
        address _token,
        uint256 _whitelistSaleStart,
        uint256 _pricePerToken,
        uint256 _pricePerTokenPresale,
        uint256 _tokenAmountToSale
    ) {
        token = IERC20(_token);
        whitelistSaleStart = _whitelistSaleStart;
        mainSaleStart = whitelistSaleStart + 86400;
        mainSaleEnd = whitelistSaleStart + 172800;
        pricePerToken = _pricePerToken;
        pricePerTokenPresale = _pricePerTokenPresale;
        token.transferFrom(msg.sender, address(this), _tokenAmountToSale);
        totalSaleSupply = _tokenAmountToSale;
    }

    function whitelistSaleBuy() public payable {
        require(
            block.timestamp > whitelistSaleStart &&
                block.timestamp < mainSaleStart,
            "Whitelist Sale not active"
        );
        require(msg.value > 0, "You have sent no value.");
        valuePaid[msg.sender] += msg.value;
        tokenBougth[msg.sender] += msg.value / pricePerTokenPresale;
        emit TokenBougth(msg.sender, msg.value / pricePerTokenPresale);
    }

    function mainBuy() public payable {
        require(
            block.timestamp > mainSaleStart && block.timestamp < mainSaleEnd,
            "Whitelist Sale didn't start yet"
        );
        require(msg.value > 0, "You have sent no value.");
        valuePaid[msg.sender] += msg.value;
        tokenBougth[msg.sender] += msg.value / pricePerToken;
        emit TokenBougth(msg.sender, msg.value / pricePerToken);
    }

    function fulfillILO() public {
        require(!iloFulfilled, "ILO already Fulfilled");
        depositLiquidity();
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
            token.transfer(msg.sender, _amountToSend);
            emit Withdrawal(msg.sender, _amountToSend);
        }
    }

    function depositLiquidity() internal {}

    function withdrawOwner() public {}
}
