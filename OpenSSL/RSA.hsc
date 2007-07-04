{- -*- haskell -*- -}

#include "HsOpenSSL.h"

-- #prune

-- |An interface to RSA public key generator.

module OpenSSL.RSA
    ( -- * Type
      RSA
    , RSA_ -- private
    , withRSAPtr -- private

      -- * Generating keypair
    , RSAGenKeyCallback
    , generateKey

      -- * Exploring keypair
    , rsaN
    , rsaE
    , rsaD
    , rsaP
    , rsaQ
    , rsaDMP1
    , rsaDMQ1
    , rsaIQMP
    )
    where

import           Control.Monad
import           Foreign
import           Foreign.C
import           OpenSSL.BN
import           OpenSSL.Utils

-- |@'RSA'@ is an opaque object that represents either RSA public key
-- or public\/private keypair.
newtype RSA  = RSA (ForeignPtr RSA_)
data    RSA_


foreign import ccall unsafe "&RSA_free"
        _free :: FunPtr (Ptr RSA_ -> IO ())


withRSAPtr :: RSA -> (Ptr RSA_ -> IO a) -> IO a
withRSAPtr (RSA rsa) = withForeignPtr rsa


{- generation --------------------------------------------------------------- -}

-- |@'RSAGenKeyCallback'@ represents a callback function to get
-- informed the progress of RSA key generation.
--
-- * @callback 0 i@ is called after generating the @i@-th potential
--   prime number.
--
-- * While the number is being tested for primality, @callback 1 j@ is
--   called after the @j@-th iteration (j = 0, 1, ...).
--
-- * When the @n@-th randomly generated prime is rejected as not
--   suitable for the key, @callback 2 n@ is called.
--
-- * When a random @p@ has been found with @p@-1 relatively prime to
--   @e@, it is called as @callback 3 0@.
--
-- * The process is then repeated for prime @q@ with @callback 3 1@.
type RSAGenKeyCallback = Int -> Int -> IO ()

type RSAGenKeyCallback' = Int -> Int -> Ptr () -> IO ()


foreign import ccall "wrapper"
        mkGenKeyCallback :: RSAGenKeyCallback' -> IO (FunPtr RSAGenKeyCallback')

foreign import ccall safe "RSA_generate_key"
        _generate_key :: Int -> Int -> FunPtr RSAGenKeyCallback' -> Ptr a -> IO (Ptr RSA_)

-- |@'generateKey'@ generates an RSA keypair.
generateKey :: Int    -- ^ The number of bits of the public modulus
                      --   (i.e. key size). Key sizes with @n < 1024@
                      --   should be considered insecure.
            -> Int    -- ^ The public exponent. It is an odd number,
                      --   typically 3, 17 or 65537.
            -> Maybe RSAGenKeyCallback -- ^ A callback function.
            -> IO RSA -- ^ The generated keypair.

generateKey nbits e Nothing
    = do ptr <- _generate_key nbits e nullFunPtr nullPtr
         failIfNull ptr
         newForeignPtr _free ptr >>= return . RSA

generateKey nbits e (Just cb)
    = do cbPtr <- mkGenKeyCallback
                  $ \ arg1 arg2 _ -> cb arg1 arg2
         ptr   <- _generate_key nbits e cbPtr nullPtr
         freeHaskellFunPtr cbPtr
         failIfNull ptr
         newForeignPtr _free ptr >>= return . RSA


{- exploration -------------------------------------------------------------- -}

peekRSAPublic :: (Ptr RSA_ -> IO (Ptr BIGNUM)) -> RSA -> IO Integer
peekRSAPublic peeker rsa
    = withRSAPtr rsa $ \ rsaPtr ->
      do bn <- peeker rsaPtr
         when (bn == nullPtr) $ fail "peekRSAPublic: got a nullPtr"
         peekBN bn


peekRSAPrivate :: (Ptr RSA_ -> IO (Ptr BIGNUM)) -> RSA -> IO (Maybe Integer)
peekRSAPrivate peeker rsa
    = withRSAPtr rsa $ \ rsaPtr ->
      do bn <- peeker rsaPtr
         if bn == nullPtr then
             return Nothing
           else
             peekBN bn >>= return . Just

-- |@'rsaN' pubKey@ returns the public modulus of the key.
rsaN :: RSA -> IO Integer
rsaN = peekRSAPublic (#peek RSA, n)

-- |@'rsaE' pubKey@ returns the public exponent of the key.
rsaE :: RSA -> IO Integer
rsaE = peekRSAPublic (#peek RSA, e)

-- |@'rsaD' privKey@ returns the private exponent of the key. If
-- @privKey@ is not really a private key, the result is @Nothing@.
rsaD :: RSA -> IO (Maybe Integer)
rsaD = peekRSAPrivate (#peek RSA, d)

-- |@'rsaP' privkey@ returns the secret prime factor @p@ of the key.
rsaP :: RSA -> IO (Maybe Integer)
rsaP = peekRSAPrivate (#peek RSA, p)

-- |@'rsaQ' privkey@ returns the secret prime factor @q@ of the key.
rsaQ :: RSA -> IO (Maybe Integer)
rsaQ = peekRSAPrivate (#peek RSA, q)

-- |@'rsaDMP1' privkey@ returns @d mod (p-1)@ of the key.
rsaDMP1 :: RSA -> IO (Maybe Integer)
rsaDMP1 = peekRSAPrivate (#peek RSA, dmp1)

-- |@'rsaDMQ1' privkey@ returns @d mod (q-1)@ of the key.
rsaDMQ1 :: RSA -> IO (Maybe Integer)
rsaDMQ1 = peekRSAPrivate (#peek RSA, dmq1)

-- |@'rsaIQMP' privkey@ returns @q^-1 mod p@ of the key.
rsaIQMP :: RSA -> IO (Maybe Integer)
rsaIQMP = peekRSAPrivate (#peek RSA, iqmp)