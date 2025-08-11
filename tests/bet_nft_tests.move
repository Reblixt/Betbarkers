#[test_only]
module nft::bet_nft_tests {
    use nft::{betbarkers::{Self as Nft, Betbarkers, Config, MintCap}, profits::{Self, Profits}};
    use std::{debug::print, u64};
    use sui::{
        coin::{Self, Coin},
        sui::SUI,
        test_scenario::{Self as Scen, Scenario},
        test_utils::{destroy, assert_eq}
    };

    const Owner: address = @0x1;

    #[test]
    fun test_mint_betbarker() {
        let mut scen = Scen::begin(Owner);
        let (nft, config, mint_cap) = setup(&mut scen);

        destroy(nft);
        destroy(mint_cap);
        destroy(config);
        scen.end();
    }

    #[test]
    fun test_depoist_profit() {
        let mut scen = Scen::begin(Owner);
        let (nft, config, mint_cap) = setup(&mut scen);

        let profits = setup_deposit_profits(&mut scen, &config);

        destroy(nft);
        destroy(mint_cap);
        destroy(config);
        destroy(profits);
        scen.end();
    }

    #[test]
    fun test_claim_profit() {
        let mut scen = Scen::begin(Owner);
        let (nft, config, mint_cap) = setup(&mut scen);

        let mut profits = setup_deposit_profits(&mut scen, &config);

        let profit_balance = profits.get_balance();

        profits.claim_profit(&nft, scen.ctx());

        scen.next_tx(Owner);

        let claimed_balance = profits.get_amount_claimed();
        let profit_pet_nft = profits.get_profit_per_nft();

        assert_eq(claimed_balance, profit_pet_nft);
        assert_eq(profits.get_balance(), profit_balance - claimed_balance);

        destroy(nft);
        destroy(mint_cap);
        destroy(config);
        destroy(profits);
        scen.end();
    }

    #[test, expected_failure(abort_code = ::nft::profits::EAlreadyClaimed)]
    fun test_abort_profit_already_claimed() {
        let mut scen = Scen::begin(Owner);
        let (nft, config, mint_cap) = setup(&mut scen);

        let mut profits = setup_deposit_profits(&mut scen, &config);

        profits.claim_profit(&nft, scen.ctx());

        // Attempt to claim again should fail
        scen.next_tx(Owner);
        profits.claim_profit(&nft, scen.ctx());

        destroy(nft);
        destroy(mint_cap);
        destroy(config);
        destroy(profits);
        scen.end();
    }

    // #[test, expected_failure(abort_code = ::nft::betbarkers::EMaxSupplyReached)]
    // fun test_cannot_mint_beyond_max_supply() {
    //     let mut scen = Scen::begin(Owner);
    //     let (nft, mut config, mint_cap) = setup(&mut scen);
    //
    //     let mut i = 0;
    //     while (i < 3000) {
    //         scen.next_tx(Owner);
    //         Nft::mint(
    //             b"First Betbarker".to_string(),
    //             b"https://example.com/image1.png".to_string(),
    //             b"First Betbarker Description".to_string(),
    //             10,
    //             vector[b"key1".to_string(), b"key2".to_string()],
    //             vector[b"value1".to_string(), b"value2".to_string()],
    //             &mut config,
    //             &mint_cap,
    //             scen.ctx(),
    //         );
    //         i = i + 1;
    //     };
    //
    //     destroy(nft);
    //     destroy(mint_cap);
    //     destroy(config);
    //     scen.end();
    // }

    fun setup(scen: &mut Scenario): (Betbarkers, Config, MintCap) {
        Nft::test_init(scen.ctx());

        scen.next_tx(Owner);
        let mint_cap = scen.take_from_address<Nft::MintCap>(Owner);
        let mut config = Scen::take_shared<Config>(scen);

        let nft = Nft::create_nft(
            b"First Betbarker".to_string(),
            b"https://example.com/image1.png".to_string(),
            b"First Betbarker Description".to_string(),
            10,
            vector[b"key1".to_string(), b"key2".to_string()],
            vector[b"value1".to_string(), b"value2".to_string()],
            &mut config,
            &mint_cap,
            scen.ctx(),
        );

        scen.next_tx(Owner);

        let mut i = 0;
        while (i < 10) {
            let new_nft = Nft::create_nft(
                b"First Betbarker".to_string(),
                b"https://example.com/image1.png".to_string(),
                b"First Betbarker Description".to_string(),
                10,
                vector[b"key1".to_string(), b"key2".to_string()],
                vector[b"value1".to_string(), b"value2".to_string()],
                &mut config,
                &mint_cap,
                scen.ctx(),
            );
            transfer::public_transfer(new_nft, scen.ctx().sender());
            i = i + 1;
        };
        let mint_count = config.mint_count();
        let max_supply = config.max_supply();
        assert_eq(mint_count, 11);
        assert_eq(max_supply, 3000);
        (nft, config, mint_cap)
    }

    fun setup_deposit_profits(scen: &mut Scenario, config: &Config): Profits<SUI> {
        let coin_amount: u64 = u64::pow(10, 9);
        let coin = coin::mint_for_testing<SUI>(coin_amount, scen.ctx());

        profits::deposit_profits<SUI>(
            coin,
            config,
            scen.ctx(),
        );

        scen.next_tx(Owner);
        let profits = scen.take_shared<Profits<SUI>>();
        assert_eq(coin_amount, profits.get_balance());
        profits
    }
}
