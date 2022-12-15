https://bugs.immunefi.com/dashboard/submission/14204

```bash
docker pull ghcr.io/foundry-rs/foundry:latest
docker tag ghcr.io/foundry-rs/foundry:latest foundry:latest
docker run --rm -v $PWD:/app -i -t foundry sh

cd /app
forge install
forge install transmissions11/solmate --no-commit

# before the hotfix
forge test --root /app --fork-url RPC_URL --fork-block-number 44985556 --revert-strings debug -vvv

# after the hotfix
forge test --root /app --fork-url RPC_URL --fork-block-number 47077309 --revert-strings debug -vvv
forge test --root /app --fork-url RPC_URL --fork-block-number 49427439 --revert-strings debug -vvv
```
