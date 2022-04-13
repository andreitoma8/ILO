// SPDX-License-Identifier: MIT
// Creator: andreitoma8
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../interfaces/Uniswap.sol";

contract ILO is Ownable {
    address internal immutable token;

    address internal immutable paymentToken;

    address internal immutable factory;

    address internal immutable router;

    bool public iloFulfilled = false;

    bool public iloSuccess;

    uint256 public tokensSold;

    uint256 public fundsRaised;

    uint256 public immutable minBuy;

    uint256 public immutable maxBuy;

    uint256 internal immutable totalSaleSupply;

    uint256 internal constant minBougth = 50;

    uint256 internal immutable whitelistSaleStart;

    uint256 internal immutable mainSaleStart;

    uint256 internal immutable mainSaleEnd;

    uint256 internal constant PRICE_DECIMALS = 10**10;

    // Expressed with 10 decimals: 1*(10**10) = 1
    uint256 public immutable pricePerToken;

    uint256 public immutable pricePerTokenPresale;

    uint256 public immutable salesPercentageForLiquidity;

    bytes32 internal immutable merkleRoot;

    mapping(address => uint256) tokenBougth;

    mapping(address => uint256) tokenPaid;

    event TokenBougth(address indexed buyer, uint256 indexed amountBougth);

    event Withdrawal(address indexed buyer, uint256 indexed amountWithdrawn);

    event LiquidityAddres(
        uint256 indexed tokenSold,
        uint256 indexed paymentToken,
        uint256 indexed liquidity
    );

    event LiquidityRemoved(
        uint256 indexed tokenSold,
        uint256 indexed paymentToken
    );

    constructor(
        address _token,
        address _paymentToken,
        uint256 _whitelistSaleStart,
        uint256 _pricePerToken,
        uint256 _pricePerTokenPresale,
        uint256 _tokenAmountToSale,
        uint256 _salesPercentageForLiquidity,
        uint256 _minBuy,
        uint256 _maxBuy,
        bytes32 _merkleRoot,
        address _factory,
        address _router
    ) {
        token = _token;
        paymentToken = _paymentToken;
        whitelistSaleStart = _whitelistSaleStart;
        mainSaleStart = whitelistSaleStart + 86400;
        mainSaleEnd = whitelistSaleStart + 172800;
        pricePerToken = _pricePerToken;
        pricePerTokenPresale = _pricePerTokenPresale;
        salesPercentageForLiquidity = _salesPercentageForLiquidity;
        IERC20(token).transferFrom(
            msg.sender,
            address(this),
            _tokenAmountToSale
        );
        totalSaleSupply = _tokenAmountToSale;
        minBuy = _minBuy;
        merkleRoot = _merkleRoot;
        maxBuy = _maxBuy;
        factory = _factory;
        router = _router;
    }

    function whitelistSaleBuy(uint256 _amount, bytes32[] calldata _merkleProof)
        public
        payable
    {
        require(
            block.timestamp > whitelistSaleStart &&
                block.timestamp < mainSaleStart,
            "Whitelist Sale not active"
        );
        require(
            _amount > minBuy && _amount < maxBuy,
            "Your transaction value is below minimum buy"
        );
        bytes32 leaf = keccak256(abi.encodePacked((msg.sender)));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid proof"
        );
        IERC20(paymentToken).transferFrom(msg.sender, address(this), _amount);
        tokenPaid[msg.sender] += _amount;
        tokenBougth[msg.sender] +=
            (_amount * PRICE_DECIMALS) /
            pricePerTokenPresale;
        tokensSold += (_amount * PRICE_DECIMALS) / pricePerTokenPresale;
        fundsRaised += _amount;
        emit TokenBougth(
            msg.sender,
            (_amount * PRICE_DECIMALS) / pricePerTokenPresale
        );
    }

    function mainBuy(uint256 _amount) public payable {
        require(
            block.timestamp > mainSaleStart && block.timestamp < mainSaleEnd,
            "Whitelist Sale didn't start yet"
        );
        require(
            _amount > minBuy && _amount < maxBuy,
            "Your transaction value is below minimum buy"
        );
        IERC20(paymentToken).transferFrom(msg.sender, address(this), _amount);
        tokenPaid[msg.sender] += _amount;
        tokenBougth[msg.sender] += _amount / pricePerToken;
        tokensSold += (_amount * PRICE_DECIMALS) / pricePerToken;
        fundsRaised += _amount;
        emit TokenBougth(
            msg.sender,
            (_amount * PRICE_DECIMALS) / pricePerToken
        );
    }

    function fulfillILO() public {
        require(block.timestamp > mainSaleEnd, "Sale still active");
        require(!iloFulfilled, "ILO already Fulfilled");
        if ((tokensSold * 50) / 100 > totalSaleSupply) {
            iloSuccess = true;
            uint256 paymentTokenForPool = (fundsRaised *
                salesPercentageForLiquidity) / 100;
            uint256 tokenForPool = (paymentTokenForPool * pricePerToken) /
                PRICE_DECIMALS;
            depositLiquidity(tokenForPool, paymentTokenForPool);
        } else {
            iloSuccess = false;
        }
        iloFulfilled = true;
    }

    function withdrawPublic() public {
        require(iloFulfilled, "ILO not fulfilled");
        if (iloSuccess) {
            uint256 _tokenAmountToSend = tokenBougth[msg.sender];
            tokenBougth[msg.sender] = 0;
            tokenPaid[msg.sender] = 0;
            IERC20(token).transfer(msg.sender, _tokenAmountToSend);
            emit Withdrawal(msg.sender, _tokenAmountToSend);
        } else {
            uint256 _amountToSend = tokenPaid[msg.sender];
            tokenBougth[msg.sender] = 0;
            tokenPaid[msg.sender] = 0;
            (bool os, ) = payable(msg.sender).call{value: _amountToSend}("");
            require(os);
            emit Withdrawal(msg.sender, _amountToSend);
        }
    }

    function depositLiquidity(
        uint256 _amountSoldToken,
        uint256 _amountPaymentToken
    ) internal {
        IERC20(token).approve(router, _amountSoldToken);
        IERC20(token).approve(router, _amountPaymentToken);
        (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        ) = IUniswapV2Router(router).addLiquidity(
                token,
                paymentToken,
                _amountSoldToken,
                _amountPaymentToken,
                1,
                1,
                address(this),
                block.timestamp + 86400
            );
        emit LiquidityAddres(amountA, amountB, liquidity);
    }

    function withdrawOwner() public onlyOwner {
        require(iloFulfilled, "ILO is not over");
        if (iloSuccess) {
            uint256 amountToWithdraw = IERC20(paymentToken).balanceOf(
                address(this)
            );
            IERC20(paymentToken).transferFrom(
                address(this),
                owner(),
                amountToWithdraw
            );
            IERC20(token).transferFrom(
                address(this),
                owner(),
                totalSaleSupply - tokensSold
            );
        } else {
            IERC20(token).transferFrom(address(this), owner(), totalSaleSupply);
        }
    }

    function removeLiquidity() public onlyOwner {
        require(
            block.timestamp > mainSaleEnd + 15778463,
            "Liquidity is still locked"
        );
        address pair = IUniswapV2Factory(factory).getPair(token, paymentToken);
        uint256 liquidity = IERC20(pair).balanceOf(address(this));
        IERC20(pair).approve(router, liquidity);
        (uint256 amountA, uint256 amountB) = IUniswapV2Router(router)
            .removeLiquidity(
                token,
                paymentToken,
                liquidity,
                1,
                1,
                owner(),
                block.timestamp + 86400
            );
        emit LiquidityRemoved(amountA, amountB);
    }
}
