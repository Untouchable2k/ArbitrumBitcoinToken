// Arbitrum Bitcoin - ArbiBTC

// Contract is able to print multiple cryptocurrencies at once using Proof-oF-Work
//   
// Credits: 0xBitcoin, Vether, The Guild
// Network Arbitrum
//
// ----------------------------------------------------------------------------1

// Symbol      : Arbitrum
// Decimals    : 8
// Name        : ArbiBitcoin - ArbiBTC

// Total supply: 42,00,000.00
//   =
// 21,000,000 Mined over ~100+ years using Bitcoins Distrubtion halvings every 4 years. Uses Proof-oF-Work to distribute the tokens. Public Miner is available
//   +
// 21,000,000 Auctioned over 100 years in 4 day auctions split fairly among all buyers. ALL ETH proceeds go back into Miners pockets via the contract to pay for Transaction costs!!!
//      20% of of the Auction ArbiBTC goes to Holders in The_ATM_Guild contract, split among ArbiBitcoin 
//
// No premine, dev cut, or advantage taken at launch. Public miner and public pool available at launch.

// Mints forever for every token
// Send this contract any ERC20 token and it will become instantly mineable and distribute forever!!

//Viva la Mineables!!! Send this contract any ERC20 complient token (Wrapped NFTs incoming!) and we will reward a miner with it!

//pThirdDifficulty allows for the difficulty to be cut in a third.  So difficulty 10,000 becomes 3,333.  Costs 1 ETH  Makes mining 3x easier

pragma solidity ^0.8.0;

contract Ownable {
    address public owner;

    event TransferOwnership(address _from, address _to);

    constructor() public {
        owner = msg.sender;
        emit TransferOwnership(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    function setOwner(address _owner) external onlyOwner {
        emit TransferOwnership(owner, _owner);
        owner = _owner;
    }
}




library IsContract {
    function isContract(address _addr) internal view returns (bool) {
        bytes32 codehash;
        /* solium-disable-next-line */
        assembly { codehash := extcodehash(_addr) }
        return codehash != bytes32(0) && codehash != bytes32(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470);
    }
}

// File: contracts/utils/SafeMath.sol

library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256) {
        uint256 z = x + y;
        require(z >= x, "Add overflow");
        return z;
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256) {
        require(x >= y, "Sub underflow");
        return x - y;
    }

    function mult(uint256 x, uint256 y) internal pure returns (uint256) {
        if (x == 0) {
            return 0;
        }

        uint256 z = x * y;
        require(z / x == y, "Mult overflow");
        return z;
    }

    function div(uint256 x, uint256 y) internal pure returns (uint256) {
        require(y != 0, "Div by zero");
        return x / y;
    }

    function divRound(uint256 x, uint256 y) internal pure returns (uint256) {
        require(y != 0, "Div by zero");
        uint256 r = x / y;
        if (x % y != 0) {
            r = r + 1;
        }

        return r;
    }
}

// File: contracts/utils/Math.sol

library ExtendedMath {


    //return the smaller of the two inputs (a or b)
    function limitLessThan(uint a, uint b) internal pure returns (uint c) {

        if(a > b) return b;

        return a;

    }
}

// File: contracts/interfaces/IERC20.sol

interface IERC20 {
	function totalSupply() external view returns (uint256);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    function transfer(address _to, uint _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
    
}


// File: contracts/commons/AddressMinHeap.sol



abstract contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes memory data) virtual public;
}


//Main contract

contract ArbiBitcoin is Ownable, IERC20, ApproveAndCallFallBack {
    //Old contract references

    using SafeMath for uint256;
    using ExtendedMath for uint;
    event Mint(address indexed from, uint reward_amount, uint epochCount, bytes32 newChallengeNumber);
    // Managment events
    event SetName(string _prev, string _new);
    event SetHeap(address _prev, address _new);
    event WhitelistTo(address _addr, bool _whitelisted);
    uint256 override public totalSupply = 42000000000000000 ;
    bytes32 private constant BALANCE_KEY = keccak256("balance");

    // game
    uint256 public constant FEE = 200;
    //BITCOININITALIZE Start
	
    uint public _totalSupply = 21000000000000000;
    uint public latestDifficultyPeriodStarted = block.number;
    uint public epochCount = 0;//number of 'blocks' mined

    uint public _BLOCKS_PER_READJUSTMENT = 256;

    //a little number
    uint public  _MINIMUM_TARGET = 2**16;
    
    uint public  _MAXIMUM_TARGET = 2**234;
    uint public miningTarget = _MAXIMUM_TARGET.div(200000000000*25);  //1000 million difficulty to start until i enable mining
    
    bytes32 public challengeNumber;   //generate a new one when a new reward is minted
    uint public rewardEra = 0;
    uint public maxSupplyForEra = (_totalSupply - _totalSupply.div( 2**(rewardEra + 1)));
    uint public reward_amount = (200 * 10**uint(decimals) ).div( 2**rewardEra );
    address public lastRewardTo;
    address payable public GUILD; //GUILD Contract
    uint256 oneEthUnit = 1000000000000000000;
    uint256 public Token2Per = 1088888888888898;
    uint256 public Token3Min=  1088888888888898;
    uint256 public mintEthBalance=0;
    uint256 public lastRewardAmount;
    uint256 public lastRewardEthBlockNumber;
    mapping(bytes32 => bytes32) solutionForChallenge;
    uint public tokensMinted;
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;
    
    // metadata
    string public name = "Arbitrum Bitcoin - Mineable Bitcoin on Arbitrum";
    string public constant symbol = "ArbiBTC";
    uint8 public constant decimals = 8;

    // fee whitelist
    mapping(address => bool) public whitelistTo;

    // heap
    // More Minters
    bool ExtraOn = false;
    bool inited = false;
    bool Aphrodite = false;
    bool Atlas = false;
    bool Titan = false;
    bool Zeus = false;
    
    uint256 public sendb;
    function init(address addrOfProofOfBurn, address payable AddGuild) external onlyOwner{
        uint x = 2100000000000000;
        // Only init once
        assert(!inited);
        inited = true;

        
        _totalSupply = 21000000 * 10**uint(8);
    	//bitcoin commands short and sweet //sets to previous difficulty
    	miningTarget = _MAXIMUM_TARGET.div(1); //(1000000);
    	rewardEra = 0;
    //	latestDifficultyPeriodStarted = block.number;
    	
    //	_startNewMiningEpoch(rewardEra);
    	tokensMinted = reward_amount * epochCount;
    	
    	
        // Init contract variables and mint
        balances[addrOfProofOfBurn] = x;
        emit Transfer(address(0), addrOfProofOfBurn, x);
        GUILD = payable(AddGuild);
        
    }
    







    ///
    // Managment
    ///
    // first
            


    

//3x Easier difficulty in mining costs 1 Arbitrum ETH
function pThirdDifficulty() public payable {
    require(msg.value >= 1 * oneEthUnit, "Must send 1 or more ETH to lower difficulty by 3x");  
            
	    miningTarget = miningTarget.mult(3);
	    
	    if(miningTarget > _MAXIMUM_TARGET){
	    	miningTarget = _MAXIMUM_TARGET;
	    }
}



function pEnableExtras() public payable {
    require(msg.value >= oneEthUnit.div(2), "Must send at least 100 Matic to enable Extra Pools");
    Aphrodite = true;
    if(msg.value >= oneEthUnit)
    {
        Atlas = true;
    }
    if(msg.value >= 2 * oneEthUnit)
    {
        Titan = true;
    }
    if(msg.value >= 3 * oneEthUnit)
    {
        ExtraOn = true;
        Zeus = true;
    }
}






function mint(uint256 nonce, bytes32 challenge_digest) public returns (bool success) {

            bytes32 digest =  keccak256(abi.encodePacked(challengeNumber, msg.sender, nonce));

            //the challenge digest must match the expected
            require(digest == challenge_digest, "Old challenge_digest or wrong challenge_digest");

            //the digest must be smaller than the target
            require(uint256(digest) < miningTarget, "Digest must be smaller than miningTarget");
                
	        bytes32 solution = solutionForChallenge[challengeNumber];
            require(solution == 0x0,"This Challenge was alreday mined by someone else");  //prevent the same answer from awarding twice
	        solutionForChallenge[challengeNumber] = digest;

            tokensMinted = tokensMinted.add(reward_amount);

            reward_amount = (200 * 10**uint(decimals)).div( 2**rewardEra );

            //set readonly diagnostics data
            lastRewardTo = msg.sender;
            lastRewardAmount = reward_amount;
            lastRewardEthBlockNumber = block.number;


             _startNewMiningEpoch(lastRewardEthBlockNumber);
            

	    
            balances[msg.sender] = balances[msg.sender].add(reward_amount);
	    balances[GUILD] = balances[msg.sender].add(reward_amount.div(5));
                
            mintEthBalance = address(this).balance;
            address payable receiver = payable(msg.sender);
            if(Token2Per < mintEthBalance.div(8))
            {
                receiver.send(Token2Per);
		GUILD.send(ToKen2Per.div(2));
            }

            Mint(msg.sender, reward_amount, epochCount, challengeNumber );
           return true;
    }
        
        
function mintExtraToken(uint256 nonce, bytes32 challenge_digest, address ExtraFunds, bool freeMintOn) public returns (bool success) {
            require(ExtraFunds != address(this), "No minting our token!");
            if(freeMintOn == true)
            {
                require(FREEmint(nonce, challenge_digest, ExtraFunds), "Freemint issue");
            }
            else
            {
                require(mint(nonce,challenge_digest), "mint issue");
            }
            if(epochCount % 2 == 0)
            {      
                uint256 totalOwned = IERC20(ExtraFunds).balanceOf(address(this));
                totalOwned = (2 * totalOwned).div(100000);  //100,000 epochs = half of era, 2x the reward for 1/2 of the time
                IERC20(ExtraFunds).transfer(msg.sender, totalOwned);

            }
            return true;
    }
    
    
function mintExtraExtraToken(uint256 nonce, bytes32 challenge_digest, address ExtraFunds, address ExtraFunds2) public returns (bool success) {
    require(Titan, "Whitelist it!");  //, "get on the list!");
    require(mintExtraToken(nonce, challenge_digest, ExtraFunds, ExtraOn), "Nuhuhuh0");
    require(ExtraFunds != ExtraFunds2, "annoying");
    if(epochCount % 3 == 0)
    {
        uint256 totalOwned = IERC20(ExtraFunds2).balanceOf(address(this));
        totalOwned = (3 * totalOwned).div(100000);  //100,000 epochs = half of era, 3x the reward for 1/3 of the time //no round ends here
        IERC20(ExtraFunds2).transfer(msg.sender, totalOwned);
        }
        return true;
    }
    
function mintExtraExtraExtraToken(uint256 nonce, bytes32 challenge_digest, address ExtraFunds, address ExtraFunds2, address ExtraFunds3) public returns (bool success) {
    require(Atlas, "Whitelist it!");  //, "get on the list!");
    require(ExtraFunds3 != address(this), "No minting our token!");
    require(mintExtraExtraToken(nonce, challenge_digest, ExtraFunds, ExtraFunds2), "Nuhuhuh0");
    require(ExtraFunds != ExtraFunds3, "annoying1");
    require(ExtraFunds2 != ExtraFunds3, "annoying2");
    
    if(epochCount % 7 == 0)
    {
        uint256 totalOwned = IERC20(ExtraFunds3).balanceOf(address(this));
        totalOwned = (7 * totalOwned).divRound(100000);  //100,000 epochs = half of era, 7x the reward for 1/7 of the time
        IERC20(ExtraFunds3).transfer(msg.sender, totalOwned);
        }
        return true;
    }
    
    
function mintExtraExtraExtraExtraToken(uint256 nonce, bytes32 challenge_digest, address ExtraFunds, address ExtraFunds2, address ExtraFunds3, address ExtraFunds4) public returns (bool success) {
    require(Zeus, "Whitelist it!");  //, "get on the list!");
    require(ExtraFunds4 != address(this), "No minting our token!");
    require(mintExtraExtraExtraToken(nonce, challenge_digest, ExtraFunds, ExtraFunds2, ExtraFunds3), "Nuhuhuh0");
    require(ExtraFunds != ExtraFunds4, "annoying5");
    require(ExtraFunds2 != ExtraFunds4, "annoying 2 and 4");
    require(ExtraFunds3 != ExtraFunds4, "annoying 3 and 4");
    if(epochCount % 13 == 0)
    {
        uint256 totalOwned = IERC20(ExtraFunds4).balanceOf(address(this));
        totalOwned = (13 * totalOwned).divRound(100000);  //100,000 epochs = half of era, 13x the reward for 1/13 of the time
        IERC20(ExtraFunds4).transfer(msg.sender, totalOwned);
    }
    return true;
}
    
    
    
function mintNewsPaperToken(uint256 nonce, bytes32 challenge_digest, address ExtraFunds, address ExtraFunds2, address ExtraFunds3, address ExtraFunds4, address ExtraFunds5) public returns (bool success) {
    require(ExtraFunds5 != address(this), "No minting our token!");
    require(mintExtraExtraExtraToken(nonce, challenge_digest, ExtraFunds, ExtraFunds2, ExtraFunds3), "Nuhuhuh0");
    require(ExtraFunds != ExtraFunds5, "annoying");
    require(ExtraFunds2 != ExtraFunds5, "annoying 2 and 5");
    require(ExtraFunds3 != ExtraFunds5, "annoying 3 and 5");
    require(ExtraFunds4 != ExtraFunds5, "annoying 4 and 5");
    if(epochCount % 23 == 0)
    {
        uint256 totalOwned = IERC20(ExtraFunds5).balanceOf(address(this));
        totalOwned = (23 * totalOwned).divRound(100000);  //100,000 epochs = half of era, 23x the reward for 1/23 of the time
        IERC20(ExtraFunds5).transfer(msg.sender, totalOwned);
    }
    return true;
}

function FREEmint(uint256 nonce, bytes32 challenge_digest, address mintED) public returns (bool success) {
    
	
            bytes32 digest =  keccak256(abi.encodePacked(challengeNumber, msg.sender, nonce));

            //the challenge digest must match the expected
            require(digest == challenge_digest, "Old challenge_digest or wrong challenge_digest");

            //the digest must be smaller than the target
            require(uint256(digest) < miningTarget, "Digest must be smaller than miningTarget");
             
	     bytes32 solution = solutionForChallenge[challengeNumber];
             require(solution == 0x0,"This Challenge was alreday mined by someone else");  //prevent the same answer from awarding twice
             solutionForChallenge[challengeNumber] = digest;

            IERC20(mintED).transfer(msg.sender, (IERC20(mintED).balanceOf(address(this))).divRound(10000)); 

            tokensMinted = tokensMinted.add(reward_amount);

            reward_amount = (200 * 10**uint(decimals) ).div( 2**rewardEra );
            //set readonly diagnostics data
            lastRewardTo = msg.sender;
            lastRewardAmount = reward_amount;
            lastRewardEthBlockNumber = block.number;

             _startNewMiningEpoch(lastRewardEthBlockNumber);

           return true;
        }


    function _startNewMiningEpoch(uint tester2) public {
        
 
      //if max supply for the era will be exceeded next reward round then enter the new era before that happens

      //40 is the final reward era, almost all tokens minted
      //once the final era is reached, more tokens will not be given out because the assert function
      if( tokensMinted.add((200 * 10**uint(decimals) ).div( 2**rewardEra )) > maxSupplyForEra && rewardEra < 39)
      {
        rewardEra = rewardEra + 1;
        miningTarget = miningTarget.div(3);
        
      }

      //set the next minted supply at which the era will change
      // total supply of MINED tokens is 2100000000000000  blatestecause of 8 decimal places
      maxSupplyForEra = _totalSupply - _totalSupply.div( 2**(rewardEra + 1));

      epochCount = epochCount.add(1);

      //every so often, readjust difficulty. Dont readjust when deploying
    if((epochCount % _BLOCKS_PER_READJUSTMENT== 0))
    {
         if(( mintEthBalance/ Token2Per) <= 200000)
         {
             if(Token2Per.div(2) > Token3Min)
             {
             Token2Per = Token2Per.div(2);
            }
         }
         else
         {
             Token2Per = Token2Per.mult(5);
         }
         
        _reAdjustDifficulty();
    }

    challengeNumber = blockhash(block.number - 1);
}




    //https://en.bitcoin.it/wiki/Difficulty#What_is_the_formula_for_difficulty.3F
    //as of 2017 the bitcoin difficulty was up to 17 zeroes, it was only 8 in the early days

    function _reAdjustDifficulty() internal {

        
        uint ethBlocksSinceLastDifficultyPeriod = block.number - latestDifficultyPeriodStarted;
        //assume 360 ethereum blocks per hour

		// One MATIC block = 2 sec blocks so 300 blocks per = 10 min
        uint epochsMined = _BLOCKS_PER_READJUSTMENT; //256

        uint targetEthBlocksPerDiffPeriod = epochsMined * 300 * 10 * 4; // One  block = 0.2 sec blocks so 3000 blocks per = 10 min * 4 = 40 min

        //if there were less eth blocks passed in time than expected
        if( ethBlocksSinceLastDifficultyPeriod < targetEthBlocksPerDiffPeriod )
        {
          uint excess_block_pct = (targetEthBlocksPerDiffPeriod.mult(100)).div( ethBlocksSinceLastDifficultyPeriod );

          uint excess_block_pct_extra = excess_block_pct.sub(100).limitLessThan(1000);
          // If there were 5% more blocks mined than expected then this is 5.  If there were 100% more blocks mined than expected then this is 100.

          //make it harder
          miningTarget = miningTarget.sub(miningTarget.div(2000).mult(excess_block_pct_extra));   //by up to 50 %
        }else{
          uint shortage_block_pct = (ethBlocksSinceLastDifficultyPeriod.mult(100)).div( targetEthBlocksPerDiffPeriod );

          uint shortage_block_pct_extra = shortage_block_pct.sub(100).limitLessThan(1000); //always between 0 and 1000

          //make it easier
          miningTarget = miningTarget.add(miningTarget.div(2000).mult(shortage_block_pct_extra));   //by up to 50 %
        }



        latestDifficultyPeriodStarted = block.number;

        if(miningTarget < _MINIMUM_TARGET) //very difficult
        {
          miningTarget = _MINIMUM_TARGET;
        }

        if(miningTarget > _MAXIMUM_TARGET) //very easy
        {
          miningTarget = _MAXIMUM_TARGET;
        }
    }


    //42 m coins total
    // = 
    //21 million proof of work
    // + 
    //21 million proof of burn
    //reward begins at 200 tokens per and is cut in half every reward era(3-4 years)

    


        //help debug mining software
     function checkMintSolution(uint256 nonce, bytes32 challenge_digest, bytes32 challenge_number, uint testTarget) public view returns (bool success) {

        bytes32 digest = bytes32(keccak256(abi.encodePacked(challenge_number,msg.sender,nonce)));

        if(uint256(digest) > testTarget) revert();

        return (digest == challenge_digest);
        }
		
		

    //this is a recent ethereum block hash, used to prevent pre-mining future blocks
    function getChallengeNumber() public view returns (bytes32) {
        return challengeNumber;
    }

    //the number of zeroes the digest of the PoW solution requires.  Auto adjusts
     function getMiningDifficulty() public view returns (uint) {
        return _MAXIMUM_TARGET.div(miningTarget);
    }

    function getMiningTarget() public view returns (uint) {
       return miningTarget;
   }



    //21m coins total
    //reward begins at 50 and is cut in half every reward era (as tokens are mined)
    function getMiningReward() public view returns (uint) {
        //once we get half way thru the coins, only get 25 per block

         //every reward era, the reward amount halves.

         return (200 * 10**uint(decimals) ).div( 2**rewardEra ) ;

    }

    //help debug mining software
    function getMintDigest(uint256 nonce, bytes32 challenge_digest, bytes32 challenge_number) public view returns (bytes32 digesttest) {

            bytes32 digest =  keccak256(abi.encodePacked(challengeNumber, msg.sender, nonce));

        return digest;

      }



    // ------------------------------------------------------------------------

    // Total supply

    // ------------------------------------------------------------------------





    // ------------------------------------------------------------------------

    // Get the token balance for account `tokenOwner`

    // ------------------------------------------------------------------------

    function balanceOf(address tokenOwner) public override view returns (uint balance) {

        return balances[tokenOwner];

    }



    // ------------------------------------------------------------------------

    // Transfer the balance from token owner's account to `to` account

    // - Owner's account must have sufficient balance to transfer

    // - 0 value transfers are allowed

    // ------------------------------------------------------------------------

    function transfer(address to, uint tokens) public override returns (bool success) {

        balances[msg.sender] = balances[msg.sender].sub(tokens);

        balances[to] = balances[to].add(tokens);

        Transfer(msg.sender, to, tokens);

        return true;

    }



    // ------------------------------------------------------------------------

    // Token owner can approve for `spender` to transferFrom(...) `tokens`

    // from the token owner's account

    //

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md

    // recommends that there are no checks for the approval double-spend attack

    // as this should be implemented in user interfaces

    // ------------------------------------------------------------------------

    function approve(address spender, uint tokens) public override returns (bool success) {

        allowed[msg.sender][spender] = tokens;

        Approval(msg.sender, spender, tokens);

        return true;

    }



    // ------------------------------------------------------------------------

    // Transfer `tokens` from the `from` account to the `to` account

    //

    // The calling account must already have sufficient tokens approve(...)-d

    // for spending from the `from` account and

    // - From account must have sufficient balance to transfer

    // - Spender must have sufficient allowance to transfer

    // - 0 value transfers are allowed

    // ------------------------------------------------------------------------

    function transferFrom(address from, address to, uint tokens) public override returns (bool success) {

        balances[from] = balances[from].sub(tokens);

        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);

        balances[to] = balances[to].add(tokens);

        Transfer(from, to, tokens);

        return true;

    }


    // ------------------------------------------------------------------------

    // Returns the amount of tokens approved by the owner that can be

    // transferred to the spender's account

    // ------------------------------------------------------------------------

    function allowance(address tokenOwner, address spender) public override view returns (uint remaining) {

        return allowed[tokenOwner][spender];

    }



    // ------------------------------------------------------------------------

    // Token owner can approve for `spender` to transferFrom(...) `tokens`

    // from the token owner's account. The `spender` contract function

    // `receiveApproval(...)` is then executed

    // ------------------------------------------------------------------------

    function receiveApproval(address from, uint256 tokens, address token, bytes memory data) public override{
      require(token == address(this));
      
       IERC20(address(this)).transfer(from, tokens);  
    }
    





    receive() external payable {
    }
        
}
