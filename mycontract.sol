// Please paste your contract's solidity code here
// Note that writing a contract here WILL NOT deploy it and allow you to access it from your client
// You should write and develop your contract in Remix and then, before submitting, copy and paste it here

pragma solidity >=0.8.0 <0.9.0;

contract BlockchainSplitwise {
    struct OweStats {
        uint32 amount;
        bool exists;
    }

    struct UserInfo {
        mapping (address => OweStats) owes;
        address[] owing_users;
        uint last_activity;
    }

    address[] private _users;
    mapping (address => UserInfo) private _ledger;

    function get_last_activity(address user_addr) public view returns (uint) {
        return _ledger[user_addr].last_activity;
    }

    function get_all_users() public view returns (address[] memory) {
        return _users;
    }

    function get_owing_users(address user_addr) public view returns (address[] memory) {
        return _ledger[user_addr].owing_users;
    }

    function touch_user(address user_addr) private {
        UserInfo storage user = _ledger[user_addr];

        // insert if non existing before
        if (user.last_activity == 0) {
            _users.push(user_addr);
        }

        // put latest timestamp
        user.last_activity = block.timestamp;
    }

    function lookup(address debtor, address creditor) public view returns (uint32) {
        require(debtor != address(0), "debtor address is 0");
        require(creditor != address(0), "creditor address is 0");

        return _ledger[debtor].owes[creditor].amount;
    }

    function add_IOU(address creditor, uint32 amount, address[] calldata address_chain) public {
        require(creditor != address(0), "creditor address is 0");
        require(amount > 0, "IOU amount must be strictly positive");
        require(msg.sender != creditor, "cannot self owe");

        uint32 new_amount = _ledger[msg.sender].owes[creditor].amount + amount;
        uint32 min_debt = new_amount;
        uint32 tmp_debt;

        // validate the found cycle given by the client
        for (uint32 i = 1; i < address_chain.length; i++) {
            tmp_debt = _ledger[address_chain[i-1]].owes[address_chain[i]].amount;

            if (tmp_debt < min_debt) {
                min_debt = tmp_debt;
            }

            require(min_debt > 0, "address_chain does not constitute a cycle");
        }

        // there exists a cycle
        if (address_chain.length > 0) {
            require(address_chain[0] == creditor, "first element of address_chain must be the creditor");
            require(address_chain[address_chain.length - 1] == msg.sender,
                "last element of address_chain must be the sender address");
            new_amount -= min_debt;
        }

        // update sender's ledger
        UserInfo storage sender = _ledger[msg.sender];
        OweStats storage owe_stat = sender.owes[creditor];
        if (!owe_stat.exists) {
            owe_stat.exists = true;
            sender.owing_users.push(creditor);
        }
        owe_stat.amount = new_amount;
        touch_user(msg.sender);
        touch_user(creditor);

        // update cycle ledger
        for (uint32 i = 1; i < address_chain.length; i++) {
            _ledger[address_chain[i-1]].owes[address_chain[i]].amount -= min_debt;
        }
    }
}
