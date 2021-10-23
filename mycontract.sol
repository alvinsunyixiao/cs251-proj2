// Please paste your contract's solidity code here
// Note that writing a contract here WILL NOT deploy it and allow you to access it from your client
// You should write and develop your contract in Remix and then, before submitting, copy and paste it here

pragma solidity >=0.8.0 <0.9.0;

contract BlockchainSplitwise {
    struct DebtInfo {
        uint32 amount;
        bool exists;
    }

    struct UserInfo {
        mapping (address => DebtInfo) owes;
        address[] owing_users;
        bool exists;
    }

    address[] private _debtors;
    mapping (address => UserInfo) private _ledger;

    /**
     * Return addresses of all debtors
     **/
    function get_all_debtors() public view returns (address[] memory) {
        return _debtors;
    }

    /**
     * Return an array of addresses to which user_addr is owing debt.
     **/
    function get_owing_users(address user_addr) public view returns (address[] memory) {
        return _ledger[user_addr].owing_users;
    }

    /**
     * Lookup how much does debtor owe creditor
     **/
    function lookup(address debtor, address creditor) public view returns (uint32) {
        require(debtor != address(0), "debtor address is 0");
        require(creditor != address(0), "creditor address is 0");

        return _ledger[debtor].owes[creditor].amount;
    }

    /**
     * Add an IOU (I owe you) to the ledger
     **/
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
        if (!sender.exists) {
            _debtors.push(msg.sender);
            sender.exists = true;
        }
        if (!sender.owes[creditor].exists) {
            sender.owing_users.push(creditor);
            sender.owes[creditor].exists = true;
        }
        sender.owes[creditor].amount = new_amount;

        // update cycle ledger
        for (uint32 i = 1; i < address_chain.length; i++) {
            _ledger[address_chain[i-1]].owes[address_chain[i]].amount -= min_debt;
        }
    }
}

