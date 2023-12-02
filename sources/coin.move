module sui_nft::coin{
    use std::option;

    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Supply};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::url;
    use sui::package::{Publisher};
    use sui::vec_set::{Self, VecSet};
    use sui::event::{emit};

    const BENJI_PRE_MINT_AMOUNT: u64 = 100000000000;

    /// ERRORS
    const EMintNotAllowed: u64 = 1;
    const ENoZeroAddress: u64 = 2;

    struct BENJI has drop {}

    struct BenjiStorage has key {
        id: UID,
        supply: Supply<BENJI>,
        minters: VecSet<ID> // list of the publishers that are allowed to mint
    }

    struct BenjiAdminCap has key {
        id: UID
    }

    /// Event
    struct MinterAdded has copy, drop {
        id: ID
    }

    struct MinterRemoved has copy, drop {
        id: ID
    }

    struct NewAdmin has copy, drop {
        admin: address
    }

    fun int(withness: BENJI, ctx: &mut TxContext){
        let (treasury, metadata) = coin::create_currency<BENJI>(
            withness,
            9,
            b"BENJI",
            b"Token published by Venture23",
            b"The governance token for Venture23",
            option::none(),
            ctx
        );
        let supply = coin::treasury_into_supply(treasury);
        let increase_supply = balance::increase_supply(&mut supply, BENJI_PRE_MINT_AMOUNT);
        let into_coin = coin::from_balance(increase_supply, ctx);
        transfer::public_transfer(into_coin, @admin);

        let admin_cap = BenjiAdminCap{
            id: object::new(ctx)
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));

        let benji_storage = BenjiStorage{
            id: object::new(ctx),
            supply,
            minters: vec_set::empty()
        };

        transfer::share_object(benji_storage);

        // freeze metadata
        transfer::public_freeze_object(metadata);
    }

    /*
    * @dev It indicates if the package has right to mint BEJNI
    * @param storage The BenjiSotrage shared object
    * @param publisher of the package
    * @returns bool, true if it can mint BENJI
    */
    public fun is_minter(storage: &BenjiStorage, id: ID):bool{
        vec_set::contains(&storage.minters, &id)
    }

    /*
    * @dev Only minters can create a new Coin<BENJI>
    * @param storage The BenjiSotrage shared object
    * @param Publisher object of the package who wishes to mint BENJI
    * @returns Coin<BENJI>, new created BENJI coin
    */
    public fun mint(storage: &mut BenjiStorage, publisher: &Publisher, value: u64, ctx: &mut TxContext): Coin<BENJI>{
        assert!(is_minter(storage, object::id(publisher)), EMintNotAllowed);
        coin::from_balance(balance::increase_supply(&mut storage.supply, value), ctx)
    }

    /*
    * @dev This function allows to burn their own BENJI
    * @param storage The BenjiSotrage shared object
    * @param c The BENJI coin to burn
    */
    public fun burn(storage: &mut BenjiStorage, c: Coin<BENJI>): u64{
        balance::decrease_supply(&mut storage.supply, coin::into_balance(c))
    }

    /*
    * @dev This function can be used to transfer BENJI ta a {recipient}
    * @param c The BENJI coin to transfer
    * @param recipient The recipient of Coin<BENJI>
    */
    public entry fun transfer(c: coin::Coin<BENJI>, recipient: address){
        transfer::public_transfer(c, recipient);
    }

    /*
    * @dev It returns the total supply of the Coin<X>
    * @param storage The {BenjiStorage} shared object
    * @return the total supply in u64
    */
    public fun total_supply(storage: &BenjiStorage): u64{
        balance::supply_value(&storage.supply)
    }

    /*
    * @dev It allows the holder of the {BenjiStorage} to add a minter.
    * @param _ The BenjiAdminCap to guard the function
    * @param storage The BenjiStorage shared object
    * 
    * It emits the MinterAdded event with {ID}
    */
    public fun add_minter(_: &BenjiAdminCap, storage: &mut BenjiStorage, id: ID){
        vec_set::insert(&mut storage.minters, id);
        emit(MinterAdded{id});
    }

    /*
    * @dev It allows the holder of the {BenjiStorage} to remove a minter.
    * @param _ The BenjiAdminCap to guard the function
    * @param storage The BenjiStorage shared object
    * 
    * It emits the MinterRemoved event with {ID}
    */
    entry public fun remove_minter(_: &BenjiAdminCap, storage: &mut BenjiStorage, id: ID){
        vec_set::remove(&mut storage.minters, &id);
        emit(MinterRemoved{id});
    }

    /*
    * @dev It allows the admin to transfer right to the receipeint.
    * @param admin_cap The BenjiAdminCap to be transferred
    * @param receipient The new admin
    * 
    * It emits the NewAdmin event with new admin addredd
    */
    entry public fun transfer_admin(admin_cap: BenjiAdminCap, recipient: address){
        assert!(recipient != @0x0, ENoZeroAddress);
        transfer::transfer(admin_cap, recipient);
        emit(NewAdmin{
            admin: recipient
        });
    }
}