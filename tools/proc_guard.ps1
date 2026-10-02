# Child-process guard for the Windows tool scripts (verify.ps1, export.ps1).
# Dot-source it, then call Add-GuardedProcess $p on every process you start.
# Every guarded process joins a Job Object with KILL_ON_JOB_CLOSE owned by this
# PowerShell process, so if the script exits, is interrupted or is killed, the
# OS kills the whole tree (the Godot console wrapper and the real Godot it spawns).
# Without it, a killed verify left both Godot processes running as orphans.

if (-not ('CCProcGuard' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class CCProcGuard {
    [StructLayout(LayoutKind.Sequential)]
    struct BASIC_LIMIT {
        public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit;
        public uint LimitFlags; public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit; public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct IO_COUNTERS {
        public ulong ReadOperationCount; public ulong WriteOperationCount; public ulong OtherOperationCount;
        public ulong ReadTransferCount; public ulong WriteTransferCount; public ulong OtherTransferCount;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct EXTENDED_LIMIT {
        public BASIC_LIMIT Basic; public IO_COUNTERS Io;
        public UIntPtr ProcessMemoryLimit; public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr CreateJobObject(IntPtr attrs, string name);
    [DllImport("kernel32.dll")]
    static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref EXTENDED_LIMIT info, uint len);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);

    const int ExtendedLimitInformation = 9;
    const uint KILL_ON_JOB_CLOSE = 0x2000;
    static IntPtr job = IntPtr.Zero;

    public static bool Assign(IntPtr process) {
        if (job == IntPtr.Zero) {
            job = CreateJobObject(IntPtr.Zero, null);
            var info = new EXTENDED_LIMIT();
            info.Basic.LimitFlags = KILL_ON_JOB_CLOSE;
            SetInformationJobObject(job, ExtendedLimitInformation, ref info, (uint)Marshal.SizeOf(typeof(EXTENDED_LIMIT)));
        }
        // The job handle is never closed explicitly: it closes when this
        // process exits (normally or not), which kills every assigned process.
        return AssignProcessToJobObject(job, process);
    }
}
'@
}

function Add-GuardedProcess([System.Diagnostics.Process]$p) {
    if (-not [CCProcGuard]::Assign($p.Handle)) {
        Write-Host "  WARNING: could not attach pid $($p.Id) to the cleanup job; it may outlive this script"
    }
}

function Stop-ProcessTree([System.Diagnostics.Process]$p) {
    # taskkill /T also takes down the real Godot under the console wrapper.
    if (-not $p.HasExited) { & taskkill /T /F /PID $p.Id 2>$null | Out-Null }
}
