// Betbarkers NFT Module
// Is a module for creating and managing Betbarkers NFTs on the Sui blockchain.
// It includes minting functionality, attributes, and display setup.
module nft::betbarkers {
    use kiosk::{kiosk_lock_rule, royalty_rule};
    use std::string::String;
    use sui::{display, event::emit, package, transfer_policy};

    public struct BETBARKERS has drop {}

    // ============== Structs ==============
    public struct Config has key, store {
        id: UID,
        max_supply: u64,
        mint_count: u64,
    }

    public struct MintCap has key, store {
        id: UID,
    }

    public struct Attributes has drop, store {
        key: String,
        value: String,
    }

    public struct Betbarkers has key, store {
        id: UID,
        name: String,
        image_url: String,
        description: String,
        attributes: vector<Attributes>,
        rarity: u64,
    }

    // ============== Errors ==============
    const EMaxSupplyReached: u64 = 0;

    // ============== Events ==============

    public struct MintNftEvent has copy, drop {
        nft_id: ID,
    }

    fun init(otw: BETBARKERS, ctx: &mut TxContext) {
        let pub = package::claim(otw, ctx);
        let sender = ctx.sender();
        let (tp, tp_cap) = transfer_policy::new<Betbarkers>(&pub, ctx);

        setup_display(display::new<Betbarkers>(&pub, ctx), sender);

        setup_rules(tp, tp_cap, sender);

        transfer::share_object(Config {
            id: object::new(ctx),
            max_supply: 3000,
            mint_count: 0,
        });

        transfer::public_transfer(pub, sender);
        transfer::transfer(MintCap { id: object::new(ctx) }, sender);
    }

    // ============== Entry Functions ==============
    // #[allow(lint(self_transfer))]
    public entry fun mint(
        name: String,
        image_url: String,
        description: String,
        rarity: u64,
        keys: vector<String>,
        values: vector<String>,
        config: &mut Config,
        _: &MintCap,
        ctx: &mut TxContext,
    ) {
        config.assert_mintable();

        let nft = impl_mint(name, image_url, description, rarity, keys, values, ctx);
        emit(MintNftEvent { nft_id: nft.id.to_inner() });

        //TODO: Change to transfer to a kiosk
        transfer::transfer(nft, ctx.sender());

        config.mint_count = config.mint_count + 1;
    }

    // ============== Internal Functions ==============
    fun impl_mint(
        name: String,
        image_url: String,
        description: String,
        rarity: u64,
        keys: vector<String>,
        values: vector<String>,
        ctx: &mut TxContext,
    ): Betbarkers {
        let mut attributes: vector<Attributes> = vector::empty<Attributes>();
        keys.zip_do!(values, |key, value| {
            let attr = Attributes {
                key,
                value,
            };
            vector::push_back(&mut attributes, attr);
        });

        Betbarkers {
            id: object::new(ctx),
            name,
            image_url,
            description,
            attributes,
            rarity,
        }
    }

    // ============== Getter functions ==============

    public fun mint_count(self: &Config): u64 {
        self.mint_count
    }

    public fun max_supply(self: &Config): u64 {
        self.max_supply
    }

    //TODO: Get the correct data
    #[allow(lint(self_transfer))]
    fun setup_display(mut display: display::Display<Betbarkers>, sender: address) {
        let banner_image = b"https://betbarkers.com/banner.png".to_string();
        let cover_url = b"https://betbarkers.com/cover.png".to_string();

        display.add(b"collection_name".to_string(), b"Betbarkers".to_string());
        display.add(
            b"collection_description".to_string(),
            b"Betbarkers is a collection of unique NFTs representing digital collectibles.".to_string(),
        );
        display.add(b"project_url".to_string(), b"https://betbarkers.com".to_string());
        display.add(b"creator".to_string(), b"Betbarkers Team".to_string());
        display.add(b"banner_image".to_string(), banner_image);
        display.add(b"cover_url".to_string(), cover_url);
        display.add(b"name".to_string(), b"{name}".to_string());
        display.add(b"image_url".to_string(), b"{image_url}".to_string());
        display.add(b"description".to_string(), b"{description}".to_string());
        display.add(b"rarity".to_string(), b"{rarity}".to_string());
        transfer::public_transfer(display, sender);
    }

    #[allow(lint(share_owned, self_transfer))]
    fun setup_rules(
        mut tp: transfer_policy::TransferPolicy<Betbarkers>,
        tp_cap: transfer_policy::TransferPolicyCap<Betbarkers>,
        sender: address,
        // pub: &Publisher, ctx: &mut TxContext
    ) {
        // Add the royalty rule 2 % and a minimum amount of 0.1 SUI
        royalty_rule::add(&mut tp, &tp_cap, 200, 1_000_000_00);
        kiosk_lock_rule::add(&mut tp, &tp_cap);

        transfer::public_transfer(tp_cap, sender);
        transfer::public_share_object(tp);
    }

    // ============== Assertions =============
    fun assert_mintable(config: &Config) {
        assert!(config.mint_count < config.max_supply, EMaxSupplyReached);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(BETBARKERS {}, ctx);
    }
}
