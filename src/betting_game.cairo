use starknet:: ContractAddress;

#[derive(Copy, Drop, starknet::Store, Serde)]
struct IERC20Dispatcher {
    pub contract_address: starknet::ContractAddress,
}

#[derive(Drop, Serde, Copy)]
struct TransferRequest {
    recipient: ContractAddress,
    amount: u256,
}

#[starknet::interface]
pub trait IBettingContract<TContractState> {
    fn get_prize_pool(self: @TContractState) -> u256;
    fn get_user_points(self: @TContractState, user: ContractAddress) -> u256;
    fn transfer_prize(ref self: TContractState, user: ContractAddress);
    fn place_bet(ref self: TContractState, user: ContractAddress, bet_amount: u256, token_address: ContractAddress);
    fn claim_winnings(ref self: TContractState, user: ContractAddress, token_address: ContractAddress);
}

#[starknet::contract]
mod BettingContract {
    use super::{IERC20Dispatcher};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TokensSent: TokensSent,
    }
    #[derive(Drop, starknet::Event)]
    struct TokensSent {
        token_address: ContractAddress,
        recipients: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState,) {}

    #[storage]
    struct Storage {
        prize_pool: u256,
        user_points: Map::<ContractAddress, u256>,
        user_balances: Map::<ContractAddress, u256>,
    }

    #[abi(embed_v0)]
    impl BettingContract of super::IBettingContract<ContractState> {
        fn get_prize_pool(self: @ContractState) -> u256 {
            self.prize_pool.read()
        }

        fn get_user_points(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_points.read(user)
        }

        fn transfer_prize(ref self: ContractState, user: ContractAddress){
            let pool = self.prize_pool.read();

            let current_balance = self.user_balances.read(user);
            self.user_balances.write(user, current_balance + pool);
            self.prize_pool.write(0.into());
        }

        fn place_bet(ref self: ContractState, user: ContractAddress, bet_amount: u256, token_address: ContractAddress){
        
            let current_pool = self.prize_pool.read();
            self.prize_pool.write(current_pool + bet_amount); // when user bets

            //when user bets, transfer bet amount from user wallet to contract
            let erc20_dispatcher = IERC20Dispatcher {contract_address: token_address};
            erc20_dispatcher.transfer_from(get_caller_address(), get_contract_address(), bet_amount);

            let current_points = self.user_points.read(user);
            self.user_points.write(user, current_points + 50);

        }

        fn claim_winnings(ref self: ContractState, user: ContractAddress, token_address: ContractAddress){

            // when claims the prize, transfer from contract to user wallet
            let erc20_dispatcher = IERC20Dispatcher {contract_address: token_address};
            erc20_dispatcher.transfer(recipient, amount);

         
         

            self.user_balances.write(get_caller_address(), 0.into());
        }
        
    }
}