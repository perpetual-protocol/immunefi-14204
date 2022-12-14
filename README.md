https://bugs.immunefi.com/dashboard/submission/14204

```bash
docker pull ghcr.io/foundry-rs/foundry:latest
docker tag ghcr.io/foundry-rs/foundry:latest foundry:latest
docker run -v $PWD:/app -i -t foundry sh

cd /app
forge test --fork-url RPC_URL --fork-block-number 44985556 --revert-strings debug -vvv
```
