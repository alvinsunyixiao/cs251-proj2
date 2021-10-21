// Please paste your contract's solidity code here
// Note that writing a contract here WILL NOT deploy it and allow you to access it from your client
// You should write and develop your contract in Remix and then, before submitting, copy and paste it here

pragma solidity >=0.8.0 <0.9.0;

contract BlockchainSplitwise {
    struct UserInfo {
        address addr;
        uint last_activity;
        uint[] creditor_indics;
    }

    UserInfo[] private _users;
    mapping (address => mapping (address => uint32)) private _ledger;

    function get_users() public view returns (UserInfo[] memory) {
        return _users;
    }

    function touch_user(address user_addr, int user_index) private returns (uint) {
        uint actual_user_index = uint(user_index);

        // push new user if non existing
        if (user_index < 0) {
            for (uint i = 0; i < _users.length; ++i) {
                require(_users[i].addr != user_addr, "user already exists");
            }
            actual_user_index = _users.length;
            _users.push();
            _users[actual_user_index].addr = user_addr;
        }

        require(actual_user_index < _users.length, "user_index out of range");
        require(user_addr == _users[actual_user_index].addr, "user_addr incorrect");

        _users[actual_user_index].last_activity = block.timestamp;

        return actual_user_index;
    }

    function lookup(address debtor, address creditor) public view returns (uint32) {
        require(debtor != address(0), "debtor address is 0");
        require(creditor != address(0), "creditor address is 0");

        return _ledger[debtor][creditor];
    }

    function add_IOU(address creditor, uint32 amount,
                     int debtor_index, int creditor_index,
                     uint[] calldata cycle_chain) public {
        require(creditor != address(0), "creditor address is 0");
        require(amount > 0, "IOU amount must be strictly positive");
        require(msg.sender != creditor, "cannot self owe");

        uint32 new_amount = _ledger[msg.sender][creditor] + amount;
        uint32 min_debt = new_amount;
        uint32 tmp_debt;

        // validate the found cycle given by the client
        for (uint i = 1; i < cycle_chain.length; i++) {
            tmp_debt = _ledger[_users[cycle_chain[i-1]].addr][_users[cycle_chain[i]].addr];

            if (tmp_debt < min_debt) {
                min_debt = tmp_debt;
            }

            require(min_debt > 0, "address_chain does not constitute a cycle");
        }

        // there exists a cycle
        if (cycle_chain.length > 0) {
            require(_users[cycle_chain[0]].addr == creditor, "first element of address_chain must be the creditor");
            require(_users[cycle_chain[cycle_chain.length - 1]].addr == msg.sender,
                "last element of address_chain must be the sender address");
            new_amount -= min_debt;
        }

        // create new user if necessary
        uint debtor_index_uint = touch_user(msg.sender, debtor_index);
        uint creditor_index_uint = touch_user(creditor, creditor_index);

        // update sender's ledger
        UserInfo storage debtor = _users[debtor_index_uint];
        bool add_creditor = true;
        for (uint i = 0; i < debtor.creditor_indics.length; ++i) {
            if (debtor.creditor_indics[i] == creditor_index_uint) {
                add_creditor = false;
                break;
            }
        }
        if (add_creditor) {
            debtor.creditor_indics.push(creditor_index_uint);
        }
        _ledger[msg.sender][creditor] = new_amount;

        // update cycle ledger
        for (uint i = 1; i < cycle_chain.length; i++) {
            _ledger[_users[cycle_chain[i-1]].addr][_users[cycle_chain[i]].addr] -= min_debt;
        }
    }
}
