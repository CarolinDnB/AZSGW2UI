import ctypes, sys

lua = ctypes.CDLL("liblua5.4.so.0")
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.luaL_loadfilex.restype = ctypes.c_int
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
lua.lua_pcallk.restype = ctypes.c_int
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p

L = lua.luaL_newstate()
lua.luaL_openlibs(L)
path = sys.argv[1].encode()
st = lua.luaL_loadfilex(L, path, None)
if st == 0:
    st = lua.lua_pcallk(L, 0, 0, 0, 0, None)
if st != 0:
    msg = lua.lua_tolstring(L, -1, None)
    print("LUA ERROR:", msg.decode() if msg else "?")
    sys.exit(1)
print("OK")
