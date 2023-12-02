module sui_nft::nft{
    use std::string;
    use std::option::{Self, Option};

    use sui::url::{Self, Url};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::sui::SUI;

    /// on wrong amount
    const EWrongAmount: u64 = 0;

    struct SuiNFT has key, store{
        id: UID,
        // name of the token
        name: string::String,

        // token info
        description: string::String,

        // token url
        url: Url,

        // child nft
        child_nft: Option<ID>,
    }

    /// capability to mint nft
    struct MinterCap has key {id: UID}

    /// event on suiNFT mint
    struct MintNFTEvent has copy, drop{
        // the id for nft
        object_id: ID,
        // the address of the minter
        createor: address,
        // name of the nft
        name: string::String,
    }
    struct MintingTreasury has key{
        id: UID,
        balance: Balance<SUI>,
        minting_fee: u64,
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(
            MinterCap{
                id: object::new(ctx),
            }, tx_context::sender(ctx)
        );

        let minting_treasury = MintingTreasury{
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
            minting_fee: 5000000
        };
        transfer::share_object(minting_treasury);
    }

    fun mint(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ) : SuiNFT{
        let nft = SuiNFT{
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url),
            child_nft: option::none()
        };
        // let sender = tx_context::sender(ctx);
        // todo emit event
        nft
    }

    /// public mint using sui coin
    public entry fun mint_to_account(
        minting_treasury: &mut MintingTreasury,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        fee: Coin<SUI>,
        ctx: &mut TxContext
    ){
        assert!(coin::value(&fee) == minting_treasury.minting_fee, EWrongAmount);
        // transfer payment ot treasury
        balance::join(&mut minting_treasury.balance, coin::into_balance(fee));

        // mint nft
        let nft = mint(name, description, url, ctx);
        transfer::transfer(nft, tx_context::sender(ctx));
    }

    /// public paid mint to obj
    public entry fun mint_to_object(
        minting_treasury: &mut MintingTreasury,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        fee: Coin<SUI>,
        sui_parent_nft: &mut SuiNFT,
        ctx: &mut TxContext
    ){
        assert!(coin::value(&fee) == minting_treasury.minting_fee, EWrongAmount);
        // transfer payment ot treasury
        balance::join(&mut minting_treasury.balance, coin::into_balance(fee));

        // mint nft
        let nft = mint(name, description, url, ctx);
        option::fill(&mut sui_parent_nft.child_nft, object::id(&nft));
        let nft_id = object::id(sui_parent_nft);
        transfer::transfer(nft, object::id_to_address(&nft_id));
    }

    ///  mint for minter role
    public entry fun owner_mint_to_account(
        _: &MinterCap,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ){
        let nft = mint(name, description, url, ctx);
        transfer::transfer(nft, tx_context::sender(ctx));
    }

    /// mint for minter role to child 
    public entry fun owner_mint_to_object(
         _: &MinterCap,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        sui_parent_nft: &mut SuiNFT,
        ctx: &mut TxContext
    ){
        let nft = mint(name, description, url, ctx);
        option::fill(&mut sui_parent_nft.child_nft, object::id(&nft));
        let nft_id = object::id(sui_parent_nft);
        transfer::transfer(nft, object::id_to_address(&nft_id));
    }

    public entry fun retrive_child_nft(
        child_nft: SuiNFT,
        parent_nft: &mut SuiNFT,
        ctx: &mut TxContext
    ){
        option::extract(&mut parent_nft.child_nft);
        transfer::transfer(child_nft, tx_context::sender(ctx));
    }
}