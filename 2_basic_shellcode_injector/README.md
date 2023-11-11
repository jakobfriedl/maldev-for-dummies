# Exercise 2 - Basic Shellcode Injector

## Description

Create a new project that injects your shellcode in a remote process, such as `explorer.exe`.

## Tips

This exercise is actually very similar to [Exercise 1](../Exercise%201%20-%20Basic%20Shellcode%20Loader/) in terms of implementation. The basic approach is comparable to the `VirtualAlloc()` method we saw there, except this time we are using a different API combination: `OpenProcess()` to get a handle on the target process, `VirtualAllocEx()` to allocate executable memory in the remote process, `WriteProcessMemory()` to copy the shellcode into the allocated, and `CreateRemoteThread()` to execute the shellcode as part of the target process.

> ℹ **Note:** There are plenty of alternatives to the above choice of API calls. Check out [malapi.io](https://malapi.io/) for an excellent overview of Windows API functions that can be used maliciously. Especially the 'Injection' section is relevant here!

> 😎 If you're feeling adventurous, you can use the native API (Nt-functions from `NTDLL.dll`) counterparts of these functions instead. Alternatively, look at other ways to expose your shellcode to the target process' memory, such as `NtCreateSection()` and `NtMapViewOfSection()` (example [here](https://www.ired.team/offensive-security/code-injection-process-injection/ntcreatesection-+-ntmapviewofsection-code-injection)).

### Getting a handle

Keep in mind that in order to get a handle, we need to have sufficient privileges over the target process. This generally means that you can only get a handle for a process owned by the current user, and not those owned by other users or managed by the system itself (makes sense right?). However, if you are executing from a privileged context (i.e. running as `SYSTEM` or with the `SeDebugPrivilege` enabled) you can get a handle to any process, including system processes. 

When designing malware that injects remotely, you need to be conscious about the target process that you choose. Choosing the wrong process may cause your malware to fail because the process is not present, or you have insufficient privileges. Furthermore, injecting from a privileged context into a low-privileged process will drop your privileges.

> ℹ **Note:** This is why making the target process configurable and basing it on the target environment is a good idea. You may hardcode the name or process ID of `explorer.exe` for now, we will improve that functionality in [bonus exercise 2](../BONUS%20Exercise%202%20-%20Basic%20Injector%20With%20Dynamic%20Target/).

## References

### C#

- [A simple Windows code injection example written in C#](https://andreafortuna.org/2019/03/06/a-simple-windows-code-injection-example-written-in-c/)

### Golang

- [CreateRemoteThread/main.go](https://github.com/Ne0nd0g/go-shellcode/blob/master/cmd/CreateRemoteThread/main.go)

### Nim

- [shellcode_bin.nim](https://github.com/byt3bl33d3r/OffensiveNim/blob/master/src/shellcode_bin.nim)

### Rust

- [Process_Injection_CreateRemoteThread](https://github.com/trickster0/OffensiveRust/blob/master/Process_Injection_CreateRemoteThread/src/main.rs)
- [Shellcode_Runner_Classic-rs](https://github.com/memN0ps/arsenal-rs/blob/main/shellcode_runner_classic-rs/src/main.rs)

## Solution

Example solutions are provided in the [solutions folder](solutions/). Keep in mind that there is no "right" answer, if you made it work that's a valid solution! 