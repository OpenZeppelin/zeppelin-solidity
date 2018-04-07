
import assertRevert from './helpers/assertRevert';

const Bouncer = artifacts.require('BouncerMock');

require('chai')
  .use(require('chai-as-promised'))
  .should();

const getSigner = (contract, signer) => (addr) => {
  // via: https://github.com/OpenZeppelin/zeppelin-solidity/pull/812/files
  const message = contract.address.substr(2) + addr.substr(2);
  // ^ substr because in solidity the address is a set of byes, not a string `0xabcd`
  return web3.eth.sign(signer, web3.sha3(message, { encoding: 'hex' }));
};

contract('Bouncer', ([owner, authorizedUser, anyone, bouncerAddress]) => {
  let bouncer;
  let roleBouncer, roleOwner;

  before(async () => {
    bouncer = await Bouncer.new({ from: owner });
    roleBouncer = await bouncer.ROLE_BOUNCER();
    roleOwner = await bouncer.ROLE_OWNER();
  });

  it('should have a default owner of self', async () => {
    const hasRole = await bouncer.hasRole(owner, roleOwner);
    hasRole.should.eq(true);
  });

  it('should allow owner to add a bouncer', async () => {
    await bouncer.addBouncer(bouncerAddress, { from: owner });
    const hasRole = await bouncer.hasRole(bouncerAddress, roleBouncer);
    hasRole.should.eq(true);
  });

  it('should not allow anyone to add a bouncer', async () => {
    await assertRevert(
      bouncer.addBouncer(bouncerAddress, { from: anyone })
    );
  });

  context('signatures', () => {
    let genSig;
    before(async () => {
      genSig = getSigner(bouncer, bouncerAddress);
    });

    it('should accept valid message for valid user', async () => {
      const isValid = await bouncer.checkValidSignature.call(authorizedUser, genSig(authorizedUser));
      isValid.should.eq(true);
    });
    it('should not accept invalid message for valid user', async () => {
      const isValid = await bouncer.checkValidSignature.call(authorizedUser, genSig(anyone));
      isValid.should.eq(false);
    });
    it('should not accept invalid message for invalid user', async () => {
      const isValid = await bouncer.checkValidSignature.call(anyone, 'abcd');
      isValid.should.eq(false);
    });
    it('should not accept valid message for invalid user', async () => {
      const isValid = await bouncer.checkValidSignature.call(anyone, genSig(authorizedUser));
      isValid.should.eq(false);
    });
  });
});
