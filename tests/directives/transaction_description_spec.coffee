describe "Transaction Note Directive", ->
  $compile = undefined
  $rootScope = undefined
  element = undefined
  isoScope = undefined
  Wallet = undefined
  MyWallet = undefined
  html = undefined
  
  beforeEach module("walletApp")
  beforeEach(module('templates/transaction-description.html'))
  
  beforeEach inject((_$compile_, _$rootScope_, $injector) ->
    
    
    # The injector unwraps the underscores (_) from around the parameter names when matching
    $compile = _$compile_
    $rootScope = _$rootScope_
    
    
    Wallet = $injector.get("Wallet")
    Wallet.login("test", "test")  
    
    MyWallet = $injector.get("MyWallet")
    
    $rootScope.transaction = {
            hash: "tx_hash", confirmations: 13, intraWallet: null, 
            from: {account: {index: 0, amount: 300000000}, legacyAddresses: null, externalAddresses: null}, 
            to: {account: {index: 0, amount: 300000000}, legacyAddresses: null}
            result: -300000000
          }
          
    return
  )
  
  beforeEach ->
    html = "<transaction-description transaction='transaction'></transaction-description>"
    element = $compile(html)($rootScope)
    $rootScope.$digest()
    isoScope = element.isolateScope()
  
  it "should say You", ->
    expect(element.html()).toContain '<b translate="YOU"></b>'
        
  it "should have the transaction in its scope", ->
    expect(isoScope.transaction.hash).toBe("tx_hash")
    
  it "should recognize an intra wallet transaction", ->
    isoScope.transaction.intraWallet = true
    
    element = $compile(html)($rootScope)
    $rootScope.$digest()
    
    expect(element.html()).toContain 'translate="MOVED_BITCOIN_TO"'
    
  it "should recognize sending from imported address", ->
    isoScope.transaction.to.account = null
    isoScope.transaction.from.account = null
    isoScope.transaction.from.legacyAddresses = {addressWithLargestOutput: "some_legacy_address", amount: 100000000}
    isoScope.transaction.to.externalAddresses = {addressWithLargestOutput: "1abcd", amount: 100000000}
    isoScope.transaction.result = -100000000
    
    element = $compile(html)($rootScope)
    $rootScope.$digest()
    
    expect(element.html()).not.toContain 'translate="MOVED_BITCOIN_TO"'
    expect(element.html()).toContain 'translate="SENT_BITCOIN_TO"'
 
  it "should recognize receiving to imported address", ->
   isoScope.transaction.to.account = null
   isoScope.transaction.from.account = null
   isoScope.transaction.to.legacyAddresses = {addressWithLargestOutput: "some_legacy_address", amount: 100000000}
   isoScope.transaction.from.externalAddresses = {addressWithLargestOutput: "1abcd", amount: 100000000}
   isoScope.transaction.result = 100000000
   
 
   element = $compile(html)($rootScope)
   $rootScope.$digest()
 
   expect(element.html()).not.toContain 'translate="MOVED_BITCOIN_TO"'
   expect(element.html()).toContain 'translate="RECEIVED_BITCOIN_FROM"'  

  describe "send to email", ->
    beforeEach ->
      isoScope.transaction.to.account = null
      isoScope.transaction.to.email = {email:"somebody@blockchain.com","redeemedAt"}
      
      element = $compile(html)($rootScope)
      $rootScope.$digest()
      
    it "should be shown", ->
      expect(element.html()).toContain 'somebody@blockchain.com'
      
  describe "send to mobile", ->
    beforeEach ->
      isoScope.transaction.to.account = null
      isoScope.transaction.to.mobile = {number:"+1234","redeemedAt"}
      
      element = $compile(html)($rootScope)
      $rootScope.$digest()
      
    it "should be shown", ->
      expect(element.html()).toContain '+1234'
  
  return
  
    