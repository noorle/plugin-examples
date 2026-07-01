wit_bindgen::generate!({
    world: "counter-component",
    path: "./wit",
    generate_all,
});

use wasi::keyvalue::store;

struct Counter;

impl Guest for Counter {
    fn increment(name: String) -> Result<u32, String> {
        let bucket = store::open("").map_err(|e| format!("open failed: {e:?}"))?;

        let current = bucket
            .get(&name)
            .map_err(|e| format!("get failed: {e:?}"))?
            .map(|bytes| parse_counter(&bytes))
            .transpose()?
            .unwrap_or(0);

        let next = current
            .checked_add(1)
            .ok_or_else(|| "counter overflow".to_string())?;

        bucket
            .set(&name, &next.to_le_bytes())
            .map_err(|e| format!("set failed: {e:?}"))?;

        Ok(next)
    }
}

fn parse_counter(bytes: &[u8]) -> Result<u32, String> {
    let bytes: [u8; 4] = bytes
        .try_into()
        .map_err(|_| "stored counter value is corrupt".to_string())?;
    Ok(u32::from_le_bytes(bytes))
}

export!(Counter);
