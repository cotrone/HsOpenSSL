{- -*- haskell -*- -}

-- #hide

#include "HsOpenSSL.h"

module OpenSSL.Objects
    ( ObjNameType(..)
    , getObjNames
    )
    where

import           Data.IORef
import           Foreign
import           Foreign.C


type ObjName  = Ptr OBJ_NAME
data OBJ_NAME = OBJ_NAME

type DoAllCallback = ObjName -> Ptr () -> IO ()


foreign import ccall safe "OBJ_NAME_do_all"
        _NAME_do_all :: Int -> FunPtr DoAllCallback -> Ptr () -> IO ()

foreign import ccall safe "OBJ_NAME_do_all_sorted"
        _NAME_do_all_sorted :: Int -> FunPtr DoAllCallback -> Ptr () -> IO ()

foreign import ccall "wrapper"
        mkDoAllCallback :: DoAllCallback -> IO (FunPtr DoAllCallback)


data ObjNameType = MDMethodType
                 | CipherMethodType
                 | PKeyMethodType
                 | CompMethodType

objNameTypeToInt :: ObjNameType -> Int
objNameTypeToInt MDMethodType     = #const OBJ_NAME_TYPE_MD_METH
objNameTypeToInt CipherMethodType = #const OBJ_NAME_TYPE_CIPHER_METH
objNameTypeToInt PKeyMethodType   = #const OBJ_NAME_TYPE_PKEY_METH
objNameTypeToInt CompMethodType   = #const OBJ_NAME_TYPE_COMP_METH


iterateObjNames :: ObjNameType -> Bool -> (ObjName -> IO ()) -> IO ()
iterateObjNames nameType wantSorted cb
    = do cbPtr <- mkDoAllCallback $ \ name _ -> cb name
         let action = if wantSorted then
                          _NAME_do_all_sorted
                      else
                          _NAME_do_all
         action (objNameTypeToInt nameType) cbPtr nullPtr
         freeHaskellFunPtr cbPtr


objNameStr :: ObjName -> IO String
objNameStr name
    = do strPtr <- (#peek OBJ_NAME, name) name
         peekCString strPtr


getObjNames :: ObjNameType -> Bool -> IO [String]
getObjNames nameType wantSorted
    = do listRef <- newIORef []
         iterateObjNames nameType wantSorted $ \ name ->
             do nameStr <- objNameStr name
                modifyIORef listRef (++ [nameStr])
         readIORef listRef