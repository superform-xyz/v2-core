package txmngr

import (
	"context"
	"math/big"
	"sync"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient/simulated"
	"github.com/stretchr/testify/assert"
	mock2 "github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
	"github.com/superform-xyz/v2-core/mocks"
	"github.com/superform-xyz/v2-core/pkg/txmngr/test"
)

const chainId = int64(1337)

var (
	simpleStorageABI *abi.ABI
)

func init() {
	var err error
	if simpleStorageABI, err = test.SimpleStorageMetaData.GetAbi(); err != nil {
		panic(err)
	}
}

// createSimulatedBackend creates a simulated backend with the basic setup
func createSimulatedBackend(t *testing.T) (*simulated.Backend, common.Address, *test.SimpleStorage, *bind.TransactOpts) {
	t.Helper()

	// Create user
	userPK, err := crypto.GenerateKey()
	require.NoError(t, err)
	userAuth, err := bind.NewKeyedTransactorWithChainID(userPK, big.NewInt(chainId))
	require.NoError(t, err)

	// Create another user
	anotherUserPK, err := crypto.GenerateKey()
	require.NoError(t, err)
	anotherUserAuth, err := bind.NewKeyedTransactorWithChainID(anotherUserPK, big.NewInt(chainId))
	require.NoError(t, err)

	// Define default balance
	balance, ok := new(big.Int).SetString("10000000000000000000000000", 10) //nolint:mnd
	require.Truef(t, ok, "failed to set balance")

	// Create simulated backend
	backend := simulated.NewBackend(map[common.Address]types.Account{
		userAuth.From:        {Balance: balance},
		anotherUserAuth.From: {Balance: balance},
	})

	// Deploy SimpleStorage contract
	ssAddr, ssTx, ss, err := test.DeploySimpleStorage(anotherUserAuth, backend.Client())
	require.NoError(t, err)
	backend.Commit()
	_, err = bind.WaitDeployed(context.Background(), backend.Client(), ssTx)
	require.NoError(t, err)

	// Get the current state
	val, err := ss.Get(&bind.CallOpts{})
	require.NoError(t, err)
	require.Equal(t, "0", val.String())

	return backend, ssAddr, ss, userAuth
}

func Test_txMngr_E2E(t *testing.T) {
	t.Run("sending 5 transactions to the mempool - not mined", func(t *testing.T) {
		backend, ssAddr, ss, userAuth := createSimulatedBackend(t)

		// Create transaction manager
		mngr := New(
			NewInmemDB(),
			map[uint64]EthClient{
				uint64(chainId): backend.Client(),
			},
			userAuth.From,
			time.Second*3, // Bump after 3 blocks
			time.Second,   // Block time
			func(uint64) (*bind.TransactOpts, error) {
				return userAuth, nil
			},
		)

		// Start transaction manager
		mngr.Start(context.Background())
		defer mngr.Stop()

		// Get currently suggested gas price
		suggestedGasPrice, err := backend.Client().SuggestGasPrice(context.Background())
		require.NoError(t, err)
		t.Log("Suggested gas price:", suggestedGasPrice)

		// Prepare tx data
		data, err := simpleStorageABI.Pack("set", big.NewInt(100))
		require.NoError(t, err)

		// Send transaction
		id, err := mngr.SendTxAsync(context.Background(), uint64(chainId), ssAddr, data, 900000)
		require.NoError(t, err)

		// Collect gas prices from the transactions from the mempool
		gasPricesMap := make(map[uint64]*types.Transaction)
		for {
			// Wait for the first tx to be broadcast
			tx, err := mngr.WaitTx(context.Background(), id)
			require.NoError(t, err)

			// Get tx from the mempool
			broadcastTx, pending, err := backend.Client().TransactionByHash(context.Background(), tx.Tx.Hash())
			require.NoError(t, err, tx.Tx.Hash())
			require.True(t, pending)
			gasPricesMap[broadcastTx.GasPrice().Uint64()] = broadcastTx

			// Expecting 5 gas price bumps
			if len(gasPricesMap) == 5 {
				break
			}
		}
		require.True(t, len(gasPricesMap) == 5)
		t.Log("Gas prices from the mempool:", gasPricesMap)

		// Wait for the transaction to be mined
		tx, err := mngr.WaitTxCompleted(context.Background(), id)
		require.NoError(t, err)
		require.Equal(t, TxStatusErrored, tx.Status)

		// Check that the value has not changed
		val, err := ss.Get(&bind.CallOpts{})
		require.NoError(t, err)
		require.Equal(t, "0", val.String())

		// Check collected transactions from the mempool
		expectedGasPrices := make(map[uint64]struct{})
		lastGasPrice := suggestedGasPrice
		for i := int64(1); i <= 5; i++ {
			lastGasPrice = bumpGasPrice(lastGasPrice, priorityCoefficient*i)
			expectedGasPrices[lastGasPrice.Uint64()] = struct{}{}
		}
		require.True(t, len(expectedGasPrices) == len(gasPricesMap))
		t.Log("Expected gas prices:", expectedGasPrices)

		for gasPrice := range gasPricesMap {
			_, ok := expectedGasPrices[gasPrice]
			require.True(t, ok)
		}
	})

	t.Run("sending 3 transactions to the mempool - mined", func(t *testing.T) {
		backend, ssAddr, ss, userAuth := createSimulatedBackend(t)

		// Create transaction manager
		mngr := New(
			NewInmemDB(),
			map[uint64]EthClient{
				uint64(chainId): backend.Client(),
			},
			userAuth.From,
			time.Second*3, // Bump after 3 blocks
			time.Second,   // Block time
			func(uint64) (*bind.TransactOpts, error) {
				return userAuth, nil
			},
		)

		// Start transaction manager
		mngr.Start(context.Background())
		defer mngr.Stop()

		// Get currently suggested gas price
		suggestedGasPrice, err := backend.Client().SuggestGasPrice(context.Background())
		require.NoError(t, err)
		t.Log("Suggested gas price:", suggestedGasPrice)

		// Prepare tx data
		data, err := simpleStorageABI.Pack("add", big.NewInt(100))
		require.NoError(t, err)

		// Send transaction
		id, err := mngr.SendTxAsync(context.Background(), uint64(chainId), ssAddr, data, 900000)
		require.NoError(t, err)

		// Collect gas prices from the transactions from the mempool
		gasPricesMap := make(map[uint64]*types.Transaction)
		for {
			// Wait for the first tx to be broadcast
			tx, err := mngr.WaitTx(context.Background(), id)
			require.NoError(t, err)

			// Get tx from the mempool
			broadcastTx, pending, err := backend.Client().TransactionByHash(context.Background(), tx.Tx.Hash())
			require.NoError(t, err, tx.Tx.Hash())
			require.True(t, pending)
			gasPricesMap[broadcastTx.GasPrice().Uint64()] = broadcastTx

			// Expecting 3 gas price bumps and then mining the block
			if len(gasPricesMap) == 3 {
				backend.Commit()
				break
			}
		}
		require.True(t, len(gasPricesMap) == 3)
		t.Log("Gas prices from the mempool:", gasPricesMap)

		// Wait for the transaction to be mined
		tx, err := mngr.WaitTxCompleted(context.Background(), id)
		require.NoError(t, err)
		require.Equal(t, TxStatusSucceed, tx.Status)
		require.Equal(t, uint64(1), tx.Receipt.Status)

		// Commit one more block
		receipt, err := backend.Client().TransactionReceipt(context.Background(), tx.Receipt.TxHash)
		require.NoError(t, err)
		require.Equal(t, *receipt, *tx.Receipt)

		// Make sure the tx was actually executed
		val, err := ss.StoredData(&bind.CallOpts{})
		require.NoError(t, err)
		require.Equal(t, "100", val.String())

		// Check collected transactions from the mempool
		expectedGasPrices := make(map[uint64]struct{})
		lastGasPrice := suggestedGasPrice
		for i := int64(1); i <= 3; i++ {
			lastGasPrice = bumpGasPrice(lastGasPrice, priorityCoefficient*i)
			expectedGasPrices[lastGasPrice.Uint64()] = struct{}{}
		}
		require.True(t, len(expectedGasPrices) == len(gasPricesMap))
		t.Log("Expected gas prices:", expectedGasPrices)

		for gasPrice := range gasPricesMap {
			_, ok := expectedGasPrices[gasPrice]
			require.True(t, ok)
		}
	})
}

func Test_txMngr_Stress(t *testing.T) {
	const blockTime = time.Millisecond * 100

	backend, ssAddr, ss, userAuth := createSimulatedBackend(t)

	// Commit blocks every 100 milliseconds
	go func() {
		for {
			backend.Commit()
			time.Sleep(blockTime)
		}
	}()

	// Create transaction manager
	mngr := New(
		NewInmemDB(),
		map[uint64]EthClient{
			uint64(chainId): backend.Client(),
		},
		userAuth.From,
		blockTime*3, // Bump after 3 blocks
		blockTime,   // Block time
		func(uint64) (*bind.TransactOpts, error) {
			return userAuth, nil
		},
	)

	// Start transaction manager
	mngr.Start(context.Background())
	defer mngr.Stop()

	var wg sync.WaitGroup

	// Send 1000 transactions
	ids := make([]string, 100)
	for i := int64(1); i <= 100; i++ {
		wg.Add(1)
		go func(i int64) {
			defer wg.Done()

			// Prepare tx data
			data, err := simpleStorageABI.Pack("add", big.NewInt(100*i))
			require.NoError(t, err)

			// Send transaction
			ids[i-1], err = mngr.SendTxAsync(context.Background(), uint64(chainId), ssAddr, data, 900000)
			require.NoError(t, err)
		}(i)
	}
	wg.Wait()

	// Wait for the transactions to be mined
	for _, id := range ids {
		wg.Add(1)
		go func(id string) {
			defer wg.Done()

			tx, err := mngr.WaitTxCompleted(context.Background(), id)
			require.NoError(t, err)
			require.Equal(t, TxStatusSucceed, tx.Status)
			require.Equal(t, uint64(1), tx.Receipt.Status)
		}(id)
	}
	wg.Wait()

	// Get the state after
	val, err := ss.Get(&bind.CallOpts{})
	require.NoError(t, err)
	require.Equal(t, "505000", val.String())
}

func Test_txMngr_sendTx(t *testing.T) {
	t.Parallel()

	toAddr := common.BytesToAddress([]byte("recipient"))
	testData := []byte("test")
	testBumpInterval := time.Second / 2
	testBlockTime := time.Second

	// Create user
	userPK, err := crypto.GenerateKey()
	require.NoError(t, err)
	userAuth, err := bind.NewKeyedTransactorWithChainID(userPK, big.NewInt(1337))
	require.NoError(t, err)

	tests := []struct {
		name         string
		getClient    func(t *testing.T) *mocks.EthClient
		expectStatus string
		expectMsg    string
		expectErr    error
	}{
		{
			name: "no gas price bump",
			getClient: func(t *testing.T) *mocks.EthClient {
				cl := mocks.NewEthClient(t)

				cl.On("PendingNonceAt", mock2.Anything, userAuth.From).
					Once().
					Return(uint64(0), nil)

				cl.On("SuggestGasPrice", mock2.Anything).
					Once().
					Return(big.NewInt(100), nil)

				cl.On("SendTransaction", mock2.Anything, mock2.Anything).
					Once().
					Run(func(args mock2.Arguments) {
						tx := args.Get(1).(*types.Transaction)
						require.Equal(t, testData, tx.Data())
						require.Equal(t, toAddr, *tx.To())
						require.Equal(t, uint64(115), tx.GasPrice().Uint64(), tx.GasPrice())
					}).
					Return(nil)

				cl.On("TransactionReceipt", mock2.Anything, mock2.Anything).
					Once().
					Return(&types.Receipt{Status: 1}, nil)

				return cl
			},
			expectStatus: TxStatusSucceed,
		},
		{
			name: "one gas price bump",
			getClient: func(t *testing.T) *mocks.EthClient {
				cl := mocks.NewEthClient(t)

				// Getting nonce once
				cl.On("PendingNonceAt", mock2.Anything, userAuth.From).
					Once().
					Return(uint64(0), nil)

				// Getting gas price twice: initial gas price + gas price for the second attempt
				cl.On("SuggestGasPrice", mock2.Anything).
					Twice().
					Return(big.NewInt(100), nil)

				// Sending initial tx
				cl.On("SendTransaction", mock2.Anything, mock2.Anything).
					Once().
					Run(func(args mock2.Arguments) {
						tx := args.Get(1).(*types.Transaction)
						require.Equal(t, testData, tx.Data())
						require.Equal(t, toAddr, *tx.To())
						require.Equal(t, uint64(115), tx.GasPrice().Uint64(), tx.GasPrice())
					}).
					Return(nil)

				// Sending  tx with bumped gas price
				cl.On("SendTransaction", mock2.Anything, mock2.Anything).
					Once().
					Run(func(args mock2.Arguments) {
						tx := args.Get(1).(*types.Transaction)
						require.Equal(t, testData, tx.Data())
						require.Equal(t, toAddr, *tx.To())
						require.Equal(t, uint64(149), tx.GasPrice().Uint64(), tx.GasPrice())
					}).
					Return(nil)

				// Getting unconfirmed state first time
				cl.On("TransactionReceipt", mock2.Anything, mock2.Anything).
					Once().
					Return(nil, ethereum.NotFound)

				// Getting confirmed state second time
				cl.On("TransactionReceipt", mock2.Anything, mock2.Anything).
					Once().
					Return(&types.Receipt{Status: 1}, nil)

				return cl
			},
			expectStatus: TxStatusSucceed,
		},
		{
			name: "one gas price bump with higher suggested gas price",
			getClient: func(t *testing.T) *mocks.EthClient {
				cl := mocks.NewEthClient(t)

				// Getting nonce once
				cl.On("PendingNonceAt", mock2.Anything, userAuth.From).
					Once().
					Return(uint64(0), nil)

				// Getting initial gas price
				cl.On("SuggestGasPrice", mock2.Anything).
					Once().
					Return(big.NewInt(100), nil)

				// Getting increased gas price
				cl.On("SuggestGasPrice", mock2.Anything).
					Once().
					Return(big.NewInt(300), nil)

				// Sending initial tx
				cl.On("SendTransaction", mock2.Anything, mock2.Anything).
					Once().
					Run(func(args mock2.Arguments) {
						tx := args.Get(1).(*types.Transaction)
						require.Equal(t, testData, tx.Data())
						require.Equal(t, toAddr, *tx.To())
						require.Equal(t, uint64(115), tx.GasPrice().Uint64(), tx.GasPrice())
					}).
					Return(nil)

				// Sending tx with bumped gas price over the new suggested gas price
				cl.On("SendTransaction", mock2.Anything, mock2.Anything).
					Once().
					Run(func(args mock2.Arguments) {
						tx := args.Get(1).(*types.Transaction)
						require.Equal(t, testData, tx.Data())
						require.Equal(t, toAddr, *tx.To())
						require.Equal(t, uint64(390), tx.GasPrice().Uint64(), tx.GasPrice())
					}).
					Return(nil)

				// Getting unconfirmed state first time
				cl.On("TransactionReceipt", mock2.Anything, mock2.Anything).
					Once().
					Return(nil, ethereum.NotFound)

				// Getting confirmed state second time
				cl.On("TransactionReceipt", mock2.Anything, mock2.Anything).
					Once().
					Return(&types.Receipt{Status: 1}, nil)

				return cl
			},
			expectStatus: TxStatusSucceed,
		},
		{
			name: "fails with 5 gas price bumps",
			getClient: func(t *testing.T) *mocks.EthClient {
				cl := mocks.NewEthClient(t)

				// Getting nonce once
				cl.On("PendingNonceAt", mock2.Anything, userAuth.From).
					Once().
					Return(uint64(0), nil)

				// Getting initial gas price
				cl.On("SuggestGasPrice", mock2.Anything).
					Times(5).
					Return(big.NewInt(100), nil)

				// Sending initial tx
				cl.On("SendTransaction", mock2.Anything, mock2.Anything).
					Times(5).
					Run(func(args mock2.Arguments) {
						tx := args.Get(1).(*types.Transaction)
						require.Equal(t, toAddr, *tx.To())
						require.Equal(t, testData, tx.Data())
					}).
					Return(nil)

				// Getting unconfirmed state
				cl.On("TransactionReceipt", mock2.Anything, mock2.Anything).
					Times(5).
					Return(nil, ethereum.NotFound)

				return cl
			},
			expectStatus: TxStatusErrored,
			expectMsg:    ErrNotConfirmed.Error(),
		},
	}

	for _, tt := range tests {
		tt := tt

		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			cl := tt.getClient(t)

			// Create manager
			db := NewInmemDB()
			mngr := New(
				db,
				map[uint64]EthClient{
					uint64(chainId): cl,
				},
				userAuth.From,
				testBumpInterval,
				testBlockTime,
				func(uint64) (*bind.TransactOpts, error) {
					return userAuth, nil
				},
			)

			// Starts the tx manager
			mngr.Start(context.Background())
			defer mngr.Stop()

			// Send tx async
			txId, err := mngr.SendTxAsync(context.Background(), uint64(chainId), toAddr, []byte("test"), 100)
			require.NoError(t, err)

			// Wait for confirmation
			tx, err := mngr.WaitTxCompleted(context.Background(), txId)
			if tt.expectErr != nil {
				require.ErrorIs(t, err, tt.expectErr)
			} else {
				require.NoError(t, err)
			}

			require.Equal(t, tt.expectStatus, tx.Status)
			require.Equal(t, tt.expectMsg, tx.Msg)

			dbRecord, err := db.GetTx(context.Background(), txId)
			require.NoError(t, err)
			require.Equal(t, tt.expectStatus, dbRecord.Status)
			require.Equal(t, tt.expectMsg, dbRecord.Msg)

			cl.AssertExpectations(t)
		})
	}
}

func Test_bumpGasPrice(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name     string
		gasPrice *big.Int
		want     *big.Int
	}{
		{
			name:     "nil gas price",
			gasPrice: nil,
			want:     big.NewInt(0),
		},
		{
			name:     "zero gas price",
			gasPrice: big.NewInt(0),
			want:     big.NewInt(0),
		},
		{
			name:     "positive gas price",
			gasPrice: big.NewInt(100),
			want:     big.NewInt(115),
		},
		{
			name:     "positive gas price #2",
			gasPrice: big.NewInt(200),
			want:     big.NewInt(230),
		},
		{
			name:     "negative gas price",
			gasPrice: big.NewInt(-100),
			want:     big.NewInt(-115),
		},
	}
	for _, tt := range tests {
		tt := tt

		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			assert.Equalf(t, tt.want, bumpGasPrice(tt.gasPrice, 15), "bumpGasPrice(%v)", tt.gasPrice)
		})
	}
}
