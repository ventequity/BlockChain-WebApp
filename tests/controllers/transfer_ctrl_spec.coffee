describe "TransferControllerSpec", ->
  Wallet = undefined
  MyWallet = undefined
  scope = undefined
  rootScope = undefined
  controller = undefined

  spendableAddresses = [
    { label: 'addr1', balance: 10000 },
    { label: 'addr2', balance: 20000 }
  ]

  modalInstance =
    close: ->
    dismiss: ->

  getControllerScope = (address) ->
    s = rootScope.$new()

    controller "TransferController",
      $scope: s
      $uibModalInstance: modalInstance
      address: address

    s.$digest()
    s

  beforeEach angular.mock.module("walletApp")

  beforeEach ->
    angular.mock.inject ($injector, $rootScope, $controller, $q) ->
      rootScope = $rootScope
      controller = $controller

      Wallet = $injector.get("Wallet")
      MyWallet = $injector.get("MyWallet")
      MyWalletPayment = $injector.get("MyWalletPayment")

      makeAcct = (label, i) => label: label, index: i, incrementReceiveIndex: (->)
      Wallet.accounts = () -> ['Default', 'Savings', 'Party Money'].map(makeAcct)
      Wallet.legacyAddresses = () -> spendableAddresses
      Wallet.askForSecondPasswordIfNeeded = () -> $q.resolve('pw')
      Wallet.payment = () -> new MyWalletPayment()

      MyWallet.wallet = { hdwallet: { defaultAccount: Wallet.accounts()[0] } }
      spyOn(MyWallet.wallet.hdwallet.defaultAccount, 'incrementReceiveIndex')

      scope = getControllerScope(spendableAddresses)

  it "should select the default account", ->
    expect(scope.selectedAccount.label).toEqual('Default')

  it "should convert a single address to an array", ->
    scope = getControllerScope({ label: 'single_address' })
    expect(Array.isArray(scope.addresses)).toEqual(true)
    expect(scope.addresses[0].label).toEqual('single_address')

  it "should combine the balances of addresses", ->
    expect(scope.combinedBalance).toEqual(30000)

  it "should increment the account receive index", ->
    expect(MyWallet.wallet.hdwallet.defaultAccount.incrementReceiveIndex)
      .toHaveBeenCalled()
