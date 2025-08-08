module new_dev::testConstantAddressV4{

    use std::debug::print;
    use std::string::{String,utf8};
    use std::timestamp; 
    use std::account;
    use std::signer;
    use std::vector;
    use supra_framework::event;
    use std::table;

// Structs
    struct Headers has copy,store,drop,key {database: vector<String>}
    struct ConstantDatabase has copy,store,drop,key {database: vector<ConstantAddress>}

    struct ConstantAddress has copy,store,drop,key {header: String, name: String, value: address, editable: bool}

    #[event]
    struct ConstantAddressChange has drop, store {address: address,  old_constant: ConstantAddress, new_constant: ConstantAddress}

// Const
    const OWNER: address = @new_dev;

// Errors
    const ERROR_CONSTANT_ALREADY_EXISTS: u64 = 1;
    const ERROR_CONSTANT_DOES_NOT_EXIST: u64 = 2;
    const ERROR_NOT_ADMIN: u64 = 3;
    const ERROR_CONSTANT_CANT_BE_EDITED: u64 = 4;
    const ERROR_HEADER_IS_NOT_INNITIALIZED: u64 = 5;


// On Deploy Event
   fun init_module(address: &signer) {
        if (!exists<ConstantDatabase>(signer::address_of(address))) {
          move_to(address, ConstantDatabase { database: vector::empty()});
        };
        if (!exists<Headers>(signer::address_of(address))) {
          move_to(address, Headers { database: vector::empty()});
        };
    }

// Entry Functions


        public fun get_constantAddress_header(constant: &ConstantAddress): String{
        constant.header
    }

        public fun get_constantAddress_name(constant: &ConstantAddress): String{
        constant.name
    }

        public fun get_constantAddress_value(constant: &ConstantAddress): address{
        constant.value
    }

        public fun get_constantAddress_editable(constant: &ConstantAddress): bool{
        constant.editable
    }


    public entry fun registerHeader(address: &signer, header: String) acquires Headers {
        assert!(signer::address_of(address) == OWNER,ERROR_NOT_ADMIN);
        let db = borrow_global_mut<Headers>(OWNER);
        vector::push_back(&mut db.database, header);
    }


    public entry fun registerConstantAddress(address: &signer, header: String, constant_name: String, value: address, editable: bool) acquires ConstantDatabase, Headers {
        assert!(signer::address_of(address) == OWNER,ERROR_NOT_ADMIN);
        let db = borrow_global_mut<ConstantDatabase>(OWNER);
        let db_headers = borrow_global_mut<Headers>(OWNER);
        assert!(vector::contains(&db_headers.database, &header),ERROR_HEADER_IS_NOT_INNITIALIZED);

        let len = vector::length(&db.database);
        let i = 0;
        while (i < len) {
            let constant_ref = vector::borrow(&db.database, i);
            if (constant_ref.name == constant_name && constant_ref.header == header) {
                change_constantAddress(address, header, constant_name, value);
                return;
            };
            i = i + 1;
        };

        let constant = make_constantAddress(header, constant_name, value, editable);
        vector::push_back(&mut db.database, constant);
    }

    public entry fun registerMultipleConstantAddress(address: &signer, header: String, constant_name: vector<String>, value: vector<address>, editable: vector<bool>) acquires ConstantDatabase, Headers {

        let len = vector::length(&constant_name);
        while(len>0){
            registerConstantAddress(address, header, *vector::borrow(&constant_name, len-1), *vector::borrow(&value, len-1),*vector::borrow(&editable, len-1));
            len=len-1;
        };
    }

    public entry fun removeConstantAddress(address: &signer, header: String, constant_name: String) acquires ConstantDatabase {
        assert!(signer::address_of(address) == OWNER, ERROR_NOT_ADMIN);
        let db = borrow_global_mut<ConstantDatabase>(OWNER);
        let i = 0;
        let len = vector::length(&db.database);

        while (i < len) {
            let item_ref = vector::borrow(&db.database, i);
            if (item_ref.name == constant_name || item_ref.header == header) {
                vector::remove(&mut db.database, i);
                return
            };
            i = i + 1;
        };

        abort ERROR_CONSTANT_DOES_NOT_EXIST; 
    }


    public entry fun change_constantAddress(address: &signer, header: String, name: String, new_value: address) acquires ConstantDatabase {
        assert!(signer::address_of(address) == OWNER, 100);

        let db = borrow_global_mut<ConstantDatabase>(OWNER);
        let len = vector::length(&db.database);
        let i = 0;

        while (i < len) {
            let constant_ref = vector::borrow_mut(&mut db.database, i);
            if (constant_ref.name == name && constant_ref.header == header && constant_ref.editable) {
                let old_constant: ConstantAddress = *constant_ref;
                if (constant_ref.value != new_value) {
                    constant_ref.value = new_value;
                    event::emit(ConstantAddressChange {
                        address: signer::address_of(address),
                        old_constant: old_constant,
                        new_constant: *constant_ref,
                    });
                };
                return; //  exit after successful update
            };
            i = i + 1;
        };

        abort ERROR_CONSTANT_DOES_NOT_EXIST; //  only if nothing was updated
    }


// View Functions
    #[view]
    public fun viewConstants(): vector<ConstantAddress> acquires ConstantDatabase {
        let player_db = borrow_global<ConstantDatabase>(OWNER);
        player_db.database
    }


    #[view]
    public fun viewConstantsByHeader(header: String): vector<ConstantAddress> acquires ConstantDatabase {
        let player_db = borrow_global<ConstantDatabase>(OWNER);
        let len = vector::length(&player_db.database);
        let i = 0;
        let vect = vector::empty<ConstantAddress>();
        while (i < len) {
            let constant_ref = vector::borrow(&player_db.database, i);
            if(constant_ref.header == header){
                vector::push_back(&mut vect, *constant_ref);
            };
            i = i + 1;
        };
        move vect
    }


    #[view]
    public fun viewConstant(header: String, name: String): ConstantAddress acquires ConstantDatabase {
        let db = borrow_global_mut<ConstantDatabase>(OWNER);
        let len = vector::length(&db.database);
        let i = 0;

        while (i < len) {
            let constant_ref = vector::borrow(&db.database, i);
            if (constant_ref.name == name && constant_ref.header == header) {
                return *constant_ref
            };
            i = i + 1;
        };
        abort (ERROR_CONSTANT_DOES_NOT_EXIST)
    }

// Util Functions
    // Make
        fun make_constantAddress(header: String, name: String, value: address, editable: bool): ConstantAddress {
            ConstantAddress { header: header, name: name, value: value, editable: editable }
        }

    // Asserts
        fun assert_constant_does_not_exists(constant_name: String) acquires ConstantDatabase {
            let constant_db = borrow_global_mut<ConstantDatabase>(OWNER);
            let len = vector::length(&constant_db.database);
            while(len>0){
                let _constant = vector::borrow_mut(&mut constant_db.database, len-1);
                assert!(_constant.name != constant_name, ERROR_CONSTANT_ALREADY_EXISTS);
                len=len-1;
            };
        }

#[test(account = @0x1, owner = @0x281d0fce12a353b1f6e8bb6d1ae040a6deba248484cf8e9173a5b428a6fb74e7)]
public entry fun test(account: signer, owner: signer) acquires Headers, ConstantDatabase {
    print(&utf8(b" ACCOUNT ADDRESS "));
    print(&account);

    print(&utf8(b" OWNER ADDRESS "));
    print(&owner);

    let source_addr = signer::address_of(&account);
    init_module(&owner);
    account::create_account_for_test(source_addr);
    registerHeader(&owner,utf8(b"PlayerBaseStats") );
    registerConstant(&owner, utf8(b"PlayerBaseStats"),utf8(b"Health"), 100, false);
    registerConstant(&owner, utf8(b"PlayerBaseStats"),utf8(b"Damage"), 1, false);
    print(&viewConstant( utf8(b"PlayerBaseStats"),utf8(b"Health")));
    print(&viewConstant( utf8(b"PlayerBaseStats"),utf8(b"Damage")));

  
}}

