// This module defines the profits system for the Betbarkers NFT collection.
// It allows for the distribution of profits to NFT holders and tracks claimed profits.
module nft::profits {
    use nft::betbarkers::{Betbarkers, Config};
    use sui::{balance::Balance, coin::{Self, Coin}, event::emit, vec_set::{Self, VecSet}};

    // ============== Structs ==============
    public struct Profits<phantom C> has key, store {
        id: UID,
        profit_per_nft: u64,
        amount_claimed: u64,
        claimed: VecSet<ID>,
        balance: Balance<C>,
    }

    // ============== Events ==============

    public struct NewProfitsEvent has copy, drop {
        profit_id: ID,
        profit_per_nft: u64,
        balance: u64,
    }

    public struct ClaimProfitsEvent has copy, drop {
        nft_id: ID,
        profit_id: ID,
        amount_claimed: u64,
    }

    // ============== Errors ==============
    const EAlreadyClaimed: u64 = 0;

    // ============== Entry Functions ==============
    #[allow(lint(self_transfer))]
    public entry fun claim_profit<C>(self: &mut Profits<C>, nft: &Betbarkers, ctx: &mut TxContext) {
        let nft_id = object::id(nft);

        self.assert_not_claimed(&nft_id);
        self.claimed.insert(nft_id);

        let profit_to_claim: u64 = self.profit_per_nft;
        let coin = coin::from_balance(self.balance.split(profit_to_claim), ctx);
        self.amount_claimed = self.amount_claimed + profit_to_claim;

        transfer::public_transfer(coin, ctx.sender());

        emit(ClaimProfitsEvent {
            nft_id,
            profit_id: self.id.to_inner(),
            amount_claimed: profit_to_claim,
        });
    }

    // ============= Public Functions ==============

    public fun deposit_profits<C>(profits: Coin<C>, config: &Config, ctx: &mut TxContext) {
        let profit_uid = object::new(ctx);
        let profit_id = profit_uid.to_inner();
        let vaule = profits.value();
        let profit_per_nft = vaule / config.max_supply();

        transfer::share_object(Profits {
            id: profit_uid,
            profit_per_nft,
            amount_claimed: 0,
            claimed: vec_set::empty(),
            balance: profits.into_balance(),
        });
        emit(NewProfitsEvent {
            profit_id,
            profit_per_nft,
            balance: vaule,
        });
    }

    // ============== Getter Functions ==============

    public fun get_profit_per_nft<C>(self: &Profits<C>): u64 {
        self.profit_per_nft
    }

    public fun get_amount_claimed<C>(self: &Profits<C>): u64 {
        self.amount_claimed
    }

    public fun get_balance<C>(self: &Profits<C>): u64 {
        self.balance.value()
    }

    public fun is_claimed<C>(self: &Profits<C>, nft_id: &ID): bool {
        self.claimed.contains(nft_id)
    }

    // ============== Internal Functions ==============

    fun assert_not_claimed<C>(self: &Profits<C>, nft_id: &ID) {
        assert!(!self.claimed.contains(nft_id), EAlreadyClaimed);
    }
}
