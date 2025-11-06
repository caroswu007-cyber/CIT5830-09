// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
	mapping( address => address) public underlying_tokens;
	mapping( address => address) public wrapped_tokens;
	address[] public tokens;

	event Creation( address indexed underlying_token, address indexed wrapped_token );
	event Wrap( address indexed underlying_token, address indexed wrapped_token, address indexed to, uint256 amount );
	event Unwrap( address indexed underlying_token, address indexed wrapped_token, address frm, address indexed to, uint256 amount );

    constructor( address admin ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

	function wrap(address _underlying_token, address _recipient, uint256 _amount)
    public
    onlyRole(WARDEN_ROLE)
{
    require(_recipient != address(0), "recipient zero");
    require(_amount > 0, "amount zero");

    // 依据测试：wrapped_tokens(underlying) => wrapped
    address wrapped = wrapped_tokens[_underlying_token];
    require(wrapped != address(0), "token not registered");

    BridgeToken(wrapped).mint(_recipient, _amount);

    emit Wrap(_underlying_token, wrapped, _recipient, _amount);
}

   function unwrap(address _wrapped_token, address _recipient, uint256 _amount) public {
    require(_wrapped_token != address(0), "wrapped zero");
    require(_recipient != address(0), "recipient zero");
    require(_amount > 0, "amount zero");

    // 依据测试：underlying_tokens(wrapped) => underlying
    address underlying = underlying_tokens[_wrapped_token];
    require(underlying != address(0), "wrapped not recognized");

    // Destination 合约代表用户销毁
    BridgeToken(_wrapped_token).burn(msg.sender, _amount);

    emit Unwrap(underlying, _wrapped_token, msg.sender, _recipient, _amount);
}
	function createToken(address _underlying_token, string memory name, string memory symbol)
    public
    onlyRole(CREATOR_ROLE)
    returns (address)
{
    require(_underlying_token != address(0), "underlying zero");
    // 按测试期望：不允许已通过 wrapped_tokens 注册过的 underlying 再注册
    require(wrapped_tokens[_underlying_token] == address(0), "already registered");

    BridgeToken wrapped = new BridgeToken(name, symbol, _underlying_token, address(this));

    // 建立与测试一致的映射方向
    wrapped_tokens[_underlying_token] = address(wrapped);     // underlying => wrapped
    underlying_tokens[address(wrapped)] = _underlying_token;  // wrapped => underlying

    emit Creation(_underlying_token, address(wrapped));
    return address(wrapped);
}

}


