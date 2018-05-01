pragma solidity ^0.4.0;
contract Player {
    
    address public gameMaster;
    
    // All players who have contributed an action this round
    // for multiple moves players will be listed multiple times so payout
    // is distributed based on contribution to the round
    address[] public playersThisRound;
    
    // Current fee for an action
    uint public actionFee = 0.01 ether;
    
    // Describes action
    struct Action {
        Direction directionAction;
        Movement movementAction;
        address actionCaller;
    }
    
    // List of actions to take from
    Action[] public actionList;
    
    // current action index
    uint public actionIndex;
    
    // Driection player is facing
    enum Direction { NORTH, EAST, SOUTH, WEST }
    Direction public curDirection;
    
    // Movement enum
    enum Movement { NONE, FORWARD, BACKWARD }

    // grid - start at (0 , 0)
    struct Location {
        uint xLoc;
        uint yLoc;
    }
    Location public curLocation;
    
    constructor() public {
        gameMaster = msg.sender;
        
        // Initialize the player
        resetGame();
        
        // Initialize the map
        initializeMap();
    }
    
    /**
     * Called on death or win of the player and creation of contract
     * Reset the board.
     */
    function resetGame() private {
        delete actionList;
        delete playersThisRound;
        curDirection = Direction.NORTH;
        actionIndex = 0;
        curLocation.xLoc = 0;
        curLocation.yLoc = 0;
    }

    /**
     * turnDirectionRequest is publicly callable by those playing the game.
     * It requires an action fee which is added to the winning pot
     * directionInstruction is an uint which represents the following:
     * 0 = request to turn NORTH
     * 1 = request to turn EAST
     * 2 = request to turn SOUTH
     * 3 = request to turn WEST
     * If the caller inputs a different number other than these, 
     * there will be no change in direction
     */
    function turnDirectionRequest(uint directionInstruction) public payable {
        require(msg.value == actionFee);
        // TODO: break up actionFee into pot and developerCut (probably 10% or less)
        address actionCaller = msg.sender;
        Direction aDirection = curDirection;
        if (directionInstruction == 0) {
            aDirection = Direction.NORTH;
        } else if (directionInstruction == 1) {
            aDirection = Direction.EAST;
        } else if (directionInstruction == 2) {
            aDirection = Direction.SOUTH;
        } else if (directionInstruction == 3) {
            aDirection = Direction.WEST;
        }
        addAction(aDirection, Movement.NONE, actionCaller);
    }
    
    /**
     * movePlayerRequest is publicly callable by those playing the game.
     * It requires an action fee which is added to the winning pot
     * movementInstruction is an uint which represents the following:
     * 1 = request to move FORWARD
     * 2 = request to move BACKWARD
     * any other number = DO NOTHING
     */
    function movePlayerRequest(uint movementInstruction) public payable {
        require(msg.value == actionFee);
        // TODO: break up actionFee into pot and developerCut (probably 10% or less)
        address actionCaller = msg.sender;
        Movement aMovement = Movement.NONE;
        if (movementInstruction == 1) {
            aMovement = Movement.FORWARD;
        } else if (movementInstruction == 2) {
            aMovement = Movement.BACKWARD;
        }
        addAction(curDirection, aMovement, actionCaller);
    }
    
    /**
     * Add action to the actionList
     */
    function addAction(Direction directionInstruction, Movement movementInstruction, address actionCaller) private {
        Action memory aAction = Action(directionInstruction, movementInstruction, actionCaller);
        actionList.push(aAction);
    }
    
    /**
     * Execute oldest action on the actionList
     */
    function executeAction() public {
        require(actionIndex < actionList.length && actionList.length > 0);
        
        // Action we will execute upon.
        Action memory aAction = actionList[actionIndex];
        
        // Increment the actionIndex and playersThisRound list BEFORE executing
        // movement, because movement can fail. We still want failed moves to
        // count towards as a contribution because player may not have known 
        // it was a failing move prior to requesting.
        actionIndex = SafeMath.add(actionIndex, 1); 
        playersThisRound.push(aAction.actionCaller);
        
        // Update player location with action information
        Direction requestedDirecton = aAction.directionAction;
        Movement requestedMovement = aAction.movementAction;
        uint yLoc = curLocation.yLoc;
        uint xLoc = curLocation.xLoc;
        if (requestedDirecton == Direction.NORTH) {
            curDirection = Direction.NORTH;
            if (requestedMovement == Movement.FORWARD) {
                curLocation.yLoc = SafeMath.add(yLoc, 1);
            } else if (requestedMovement == Movement.BACKWARD) {
                require (yLoc > 0);
                curLocation.yLoc = SafeMath.sub(yLoc, 1);
            }
        } else if (requestedDirecton == Direction.EAST) {
            curDirection = Direction.EAST;
            if (requestedMovement == Movement.FORWARD) {
                curLocation.xLoc = SafeMath.add(xLoc, 1);
            } else if (requestedMovement == Movement.BACKWARD) {
                require(xLoc > 0);
                curLocation.xLoc = SafeMath.sub(xLoc, 1);
            }
        } else if (requestedDirecton == Direction.SOUTH) {
            curDirection = Direction.SOUTH;
            if (requestedMovement == Movement.FORWARD) {
                require(yLoc > 0);
                curLocation.yLoc = SafeMath.sub(yLoc, 1);
            } else if (requestedMovement == Movement.BACKWARD) {
                curLocation.yLoc = SafeMath.add(yLoc, 1);
            }
        } else { // requestedDirecton == Direction.WEST
            curDirection = Direction.WEST;
            if (requestedMovement == Movement.FORWARD) {
                require(xLoc > 0);
                curLocation.xLoc = SafeMath.sub(xLoc, 1);
            } else if (requestedMovement == Movement.BACKWARD) {
                curLocation.xLoc = SafeMath.add(xLoc, 1);
            }
        }
        
        if (getTile(curLocation.xLoc, curLocation.yLoc) == 1) {
            resetGame();
        }
    }
    
    
    function getActionListLength() public view returns (uint) {
        return actionList.length;
    }
    
    function getLastActionAdded() public view returns(Direction aDirection, Movement aMovement, address actionCaller) {
        require(actionList.length > 0);
        Action memory aAction = actionList[actionList.length - 1];
        return(aAction.directionAction, aAction.movementAction, aAction.actionCaller);
    }
    
    modifier gmOnly() {
        require(msg.sender == gameMaster);
        _;
    }
    
    function changeFee(uint256 fee) public gmOnly {
        actionFee = fee;
    }
    
    
    /**
     * GAME MAP 
     */ 
    
    uint public mapSize;
    uint[][] public map;
    
        
    function initializeMap() private {
        mapSize = 10;
        
        map = [
            [0, 0, 0, 0, 0, 1, 0, 0, 0, 0],     
            [1, 1, 1, 1, 0, 0, 1, 1, 1, 1],      //*Player start (0,0)
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],      //            WEST
            [0, 0, 0, 0, 9, 0, 0, 0, 0, 0],      //             /\
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],      //   SOUTH   <    >    NORTH
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],      //             \/
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],      //            EAST
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],      // 
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]];
    }
    
    function getTile(uint x, uint y) public view returns(uint tileType) {
        return map[x][y];
    }
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}



