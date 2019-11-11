# TODO


## Ciphertext in NTS Authenticator and Encrypted Extension Fields 

NTS auth may include ciphertext.

 * Should be deciphered.
 * Should be acessible to parser.
 * Should be read back and checked for extensions.
 * Cookie placeholders are allowed to be included i ciphertext.

## Ignore (but allow) extensions after NTS Authenticator and Encrypted Extension

 * Its valid
 * But should be ignored.
 * CW thinks there is a use-case for this; Client -> NTP Server 1 -> NTP Server 2, in which NTP Server 1 may append extensions at the end of packet.

## Kiss of Death

Signal Kiss of Death after receiving bad packet.

## Server Keys: Current Key

Many (0-4) Keys are valid for unwrapping old cookies from clients.
Only one Key is valid for wrapping new cookies. This is the current key.

ServerKeys / KeyMem should expose one register for setting current cookie generating key.
* Current Key is number (value 0-3), indicating which of Server Keys is currently generating cookies.
* Current Key should (unless mis-configured by software) point to a valid Server Key.
* If Current Key is *misconfigured* and points to an invalid Server Key, system should fail hard (fail secure) and refuse NTS handling.

Software will update keys FPGA as follows
* Phase 1
  * Key manager generates a new Server Key cemtrally
* Phase 2
  * For all FPGAs
    * Key manager sets oldest key as Invalid
    * Key manager writes new key
    * Key manager sets key as valid
  * Key manager verifies success on all FPGAs (try again until Phase 2 is successfull and/or alert human supervisors)
* Phase 3
  * For all FPGAs
    * Set new key as Current Key

## Merge NTS Verify Secure and NTS Cookie Handler

These design objects are similar (control AES-SIV, needs data from RX buffer, needs data from noncegen...).
They need to intercommunicate (transmit s2c, c2s from NTS Verify Secure to NTS Cookie Handler)

## Small things

Add TODO in code base
