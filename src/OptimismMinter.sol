import { Script } from "forge-std/Script.sol";

interface DSTokenLike {
    function mint(address,uint) external;
    function burn(address,uint) external;
}

interface USDCLike {
    function masterMinter() view external returns(address);
    function configureMinter(address minter, uint256 minterAllowedAmount) external returns (bool);
    function mint(address _to, uint256 _amount) external returns (bool);
}

interface USDTLike {
    function owner() view external returns(address);
    function transfer(address to, uint value) external;
    function issue(uint amount) external;
}

interface IL2StandardERC20 {
    function l1Token() external returns (address);

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;

    event Mint(address indexed _account, uint256 _amount);
    event Burn(address indexed _account, uint256 _amount);
}


contract Minter is Script {
    address internal constant DAIBRIDGE = 0x10E6593CDda8c58a1d0f14C5164B376352a55f2F;
    address internal constant L2BRIDGE = 0x4200000000000000000000000000000000000010;
    address internal minter = address(0x1337);

    address public constant usdt = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
    address public constant dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public constant usdc = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

    function mintUsdt(address receiver, uint256 amount) public {
        vm.deal(L2BRIDGE, 1 ether);
        vm.prank(L2BRIDGE);
        IL2StandardERC20(usdt).mint(receiver, amount);
    }

    function mintDai(address receiver, uint256 amount) public {
        vm.deal(DAIBRIDGE, 1 ether);
        vm.prank(DAIBRIDGE);
        IL2StandardERC20(dai).mint(receiver, amount);
    }

    function mintUsdc(address receiver, uint256 amount) public {

        vm.deal(L2BRIDGE, 1 ether);
        vm.prank(L2BRIDGE);
        IL2StandardERC20(usdc).mint(receiver, amount);
    }
}