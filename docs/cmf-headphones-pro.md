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
- `ECHOED`: every implemented write was changed, read back and restored on hardware.
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

## Writes

Every write was verified on hardware: the value was changed, read back, restored and read back again. Quietbar sends
each write followed by its query so the session confirms from the headphones' own answer.

| Feature | Read | Write | Values |
|---|---:|---:|---|
| Noise control | `0xC01E` (`03`) | `0xF00F` `01 v 00` | High 1, Mid 2, Low 3, Adaptive 4, Off 5, Transparency 7 |
| Spatial Audio | `0xC04F` | `0xF052` `v` | Off 0, Concert 2, Cinema 3 |
| EQ preset | `0xC050` | `0xF01D` `v` | Rock 1, Electronic 2, Pop 3, Vocals 4, Classical 5, Custom 6 |
| Custom EQ | `0xC044` | `0xF041` block | see below |
| Low lag mode | `0xC041` | `0xF040` | `01` on, `02` off |
| Dual connection | `0xC027` | `0xF01A` | `01` on, `00` off; the headphones reboot |

Responses use the request command with bit 15 cleared (for example `0xC04F` answers as `0x404F`). Battery
(`0xE001`) and noise control (`0xE003`) also arrive as unsolicited notifications.

Noise-control records are `(type, value, reserved)` triples: type 1 is the active mode, type 2 the last
noise-cancellation level. Selecting noise cancellation while in Transparency restores that last level, so Quietbar
re-sends it explicitly.

Battery payloads are a pair count followed by `(component, level)` pairs. Bit 7 of the level means charging; the
over-ear component is type 6.

Custom EQ blocks are `[3][pre-gain f32]` followed by three 13-byte records `[band][gain f32][frequency f32][Q f32]`
(little-endian; band 0 bass ≈140 Hz, 1 mid ≈980 Hz, 2 treble ≈3.5 kHz). Gains are −6…+6 dB and the pre-gain is the
negated largest boost. Quietbar edits the last block read from the headphones so their own frequency and Q values are
preserved. The read response carries trailing bytes that the headphones compute themselves; they are not written.

## Excluded features

- Standby: command identifiers exist, but safe payload units and read-back values were not proven.
- Find my headphones: a momentary start/stop action needs explicit timeout and guaranteed stop-on-close handling.
- Dual-connection device list: list records were not decoded and must not be mixed with personal device identities.
- Gesture/control remapping: configuration includes multi-field records that require exact profile preservation.
- AAC/LDAC selection: this is an Android host codec policy and is not a portable macOS device payload.
- Firmware, reset, account binding and destructive actions: intentionally unsupported.

## Remaining checks

For one reversible feature at a time:

1. Record its current queried value.
2. Change only that value.
3. Verify the queried value changes, restore the prior value, and verify restoration.
4. Capture the next value after a disconnect/reconnect.

Stop on instability, unexpected disconnects, persistent state loss or an unrecognized response code.
