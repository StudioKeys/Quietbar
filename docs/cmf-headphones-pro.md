# CMF Headphone Pro protocol note

## Scope

Authorized interoperability analysis for the CMF Headphone Pro currently paired with the author’s Nothing Phone.
Nothing X 3.10.2 was inspected from the installed split APK set. The private APK, decompiled sources and HCI bug
reports remain outside this repository.

APK evidence:

- Base SHA-256: `8c5c56b1c4f2c38281266fd8515ccbfc2fc9c4ca53bbbd3bb877b2b953771a8f`
- ARM64 split SHA-256: `fbbdfd8cadddde13576b4a7e6657e5e4d43eac06cc9e1b597c180297bbe5f18d`

Build matrix:

- Nothing Phone, Android 17, Nothing X 3.10.2
- CMF Headphone Pro, product model `B175`, BES ODM
- Bluetooth Classic RFCOMM
- macOS 26, Apple silicon

## Transport

- Service UUID: `AEAC4A03-DFF5-498F-843A-34487CF133EB`
- Runtime SDP/RFCOMM channel: 28
- Encrypted Bluetooth Classic ACL
- Observed RFCOMM MTU: 256 bytes

Evidence grades:

- `OBSERVED`: Android opened and used the custom RFCOMM service during a clean Nothing X launch; Quietbar opened
  the same service and channel on macOS and kept the link stable without reconnect.
- `STATIC`: framing, queries and individual write payloads were reconstructed from Nothing X 3.10.2 serializers.
- `EXPERIMENTAL`: writes are disabled by default and require the explicit Settings opt-in.
- `BLOCKED`: controls with incomplete read-back, rollback, host codec integration or momentary-action semantics.

## Framing

Frames are encoded as:

```text
55 | control:u16le | command:u16le | payload-length:u16le | fsn:u8 | payload | crc16:u16le?
```

- Start marker: `0x55`
- Device type: `6`
- Normal request control: `0x0660` (device type 6, multi-frame bit, CRC bit)
- Sequence: 1 through 253, then 0
- CRC: reflected CRC16, polynomial `0xA001`, initial value `0xFFFF`
- CRC coverage: all bytes before the two-byte CRC
- Maximum guarded payload in Quietbar: 4096 bytes

The implementation rejects invalid lengths and CRCs, and the stream framer buffers split input, separates coalesced
frames and recovers after corrupt data.

## Implemented read queries

| Feature | Query | Payload |
|---|---:|---|
| Protocol version | `0xC001` | empty |
| Battery | `0xC007` | empty |
| Noise control | `0xC01E` | `03` |
| EQ preset | `0xC01F` | empty |
| Low lag mode | `0xC041` | empty |
| Dual connection | `0xC027` | empty |
| Spatial Audio | `0xC04F` | empty |

Battery payloads are `type,value` pairs. The value’s high bit means charging and the low seven bits are the
percentage. Over-ear battery type `6` is preferred.

Noise-control responses are triples containing type, value and a reserved byte. Values are:

| Value | Mode |
|---:|---|
| 1 | ANC High |
| 2 | ANC Mid |
| 3 | ANC Low |
| 4 | Adaptive ANC |
| 5 | Off |
| 7 or 254 | Transparency |

## Experimental writes

Each write is followed by a query/read-back except Dual connection, whose user-visible reconnect is the read-back
boundary.

| Feature | Set command | Payload |
|---|---:|---|
| Noise control | `0xF00F` | `01 mode 00` |
| EQ preset | `0xF010` | `preset` |
| Low lag mode | `0xF040` | `01` on, `02` off |
| Dual connection | `0xF01A` | `01` on, `00` off |
| Spatial Audio | `0xF052` | `01` on, `00` off |

The write serializer is fixed by unit fixtures, but no write is sent unless the user enables **Experimental
controls** in Quietbar Settings.

## Excluded features

- Standby: command identifiers exist, but safe payload units and read-back values were not proven.
- Find my headphones: a momentary start/stop action needs explicit timeout and guaranteed stop-on-close handling.
- Dual-connection device list: list records were not decoded and must not be mixed with personal device identities.
- Gesture/control remapping: configuration includes multi-field records that require exact profile preservation.
- AAC/LDAC selection: this is an Android host codec policy and is not a portable macOS device payload.
- Custom EQ bands: profile format and unsupported-value preservation need additional fixtures.
- Firmware, reset, account binding and destructive actions: intentionally unsupported.

## Remaining checks

For one reversible feature at a time:

1. Record its current queried value.
2. Enable experimental controls and change only that value.
3. Verify the queried value changes, restore the prior value, and verify restoration.
4. Capture the next value after a disconnect/reconnect.

Stop on instability, unexpected disconnects, persistent state loss or an unrecognized response code.
