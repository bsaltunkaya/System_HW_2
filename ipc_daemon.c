#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <stdarg.h>

#define FIFO1 "/tmp/fifo1"
#define FIFO2 "/tmp/fifo2"
#define LOG_FILE "/tmp/daemon.log"
#define CMD_FIND_LARGER 1  // Command to find the larger number

// Function prototypes
void set_error(int code, const char *message, int line, const char *file);
int has_error(void);
void clear_error(void);
void handle_sigchld(int sig);
void handle_sigusr1(int sig);
void handle_sighup(int sig);
void handle_sigterm(int sig);
int ensure_fifo_exists(const char *fifo_path);
void daemonize(void);
void child_process_1(int num1, int num2);
void child_process_2(void);
void log_message(const char* format, ...);
void clean_up(int exit_code);
void write_to_log(const char* format, ...);

// Error control block structure
typedef struct {
    int error_code;
    char error_message[256];
    int line_number;
    const char *file_name;
} ErrorBlock;

// Global error block
ErrorBlock global_error_block = {0};

// Global log file descriptor
FILE* log_file = NULL;
int log_fd = -1;

// Function to set an error in the error block
void set_error(int code, const char *message, int line, const char *file) {
    global_error_block.error_code = code;
    strncpy(global_error_block.error_message, message, sizeof(global_error_block.error_message) - 1);
    global_error_block.error_message[sizeof(global_error_block.error_message) - 1] = '\0';
    global_error_block.line_number = line;
    global_error_block.file_name = file;
    
    // Log the error to stderr first (for debugging)
    fprintf(stderr, "ERROR (%s:%d): [%d] %s\n", file, line, code, message);
    
    // Log the error to the log file
    write_to_log("ERROR (%s:%d): [%d] %s", file, line, code, message);
}

// Function to write to log file directly
void write_to_log(const char* format, ...) {
    if (log_fd < 0) {
        // Open the log file if not already open
        log_fd = open(LOG_FILE, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (log_fd < 0) {
            fprintf(stderr, "Failed to open log file: %s\n", strerror(errno));
            return;
        }
    }
    
    // Get current time
    time_t now = time(NULL);
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
    
    // Format timestamp
    char timestamp[128];
    snprintf(timestamp, sizeof(timestamp), "[%s] ", time_str);
    
    // Write timestamp to log
    write(log_fd, timestamp, strlen(timestamp));
    
    // Format message
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    
    // Write message to log
    write(log_fd, buffer, strlen(buffer));
    write(log_fd, "\n", 1);
    
    // Sync to disk
    fsync(log_fd);
}

// Macro for setting errors with current file and line information
#define SET_ERROR(code, message) set_error(code, message, __LINE__, __FILE__)

// Function to check if an error has occurred
int has_error(void) {
    return global_error_block.error_code != 0;
}

// Function to clear the error
void clear_error(void) {
    global_error_block.error_code = 0;
    global_error_block.error_message[0] = '\0';
    global_error_block.line_number = 0;
    global_error_block.file_name = NULL;
}

// Log message with timestamp
void log_message(const char* format, ...) {
    va_list args;
    va_start(args, format);
    
    // Format message
    char buffer[1024];
    vsnprintf(buffer, sizeof(buffer), format, args);
    
    // Write to log
    write_to_log("%s", buffer);
    
    va_end(args);
}

volatile sig_atomic_t child_exited = 0;
volatile sig_atomic_t child_counter = 0;
volatile sig_atomic_t total_children = 2;

// Clean up function
void clean_up(int exit_code) {
    write_to_log("Starting cleanup process with exit code %d", exit_code);
    write_to_log("Child process counter: %d/%d", child_counter, total_children);
    
    // Clean up FIFOs
    if (unlink(FIFO1) == 0) {
        write_to_log("Successfully removed FIFO1");
    } else if (errno != ENOENT) {
        write_to_log("Failed to remove FIFO1: %s", strerror(errno));
    }
    
    if (unlink(FIFO2) == 0) {
        write_to_log("Successfully removed FIFO2");
    } else if (errno != ENOENT) {
        write_to_log("Failed to remove FIFO2: %s", strerror(errno));
    }
    
    write_to_log("Cleanup completed - daemon shutting down with exit code %d", exit_code);
    write_to_log("==== END OF LOG ====");
    
    // Close log file
    if (log_fd >= 0) {
        close(log_fd);
        log_fd = -1;
    }
    
    exit(exit_code);
}

// Signal handler for SIGCHLD
void handle_sigchld(int sig) {
    (void)sig; // Suppress unused parameter warning
    
    pid_t pid;
    int status;
    
    // Non-blocking wait to collect all exited children
    while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
        // Log child exit information
        if (WIFEXITED(status)) {
            write_to_log("Child process with PID %d has exited", pid);
            write_to_log("Exit status of child %d: %d", pid, WEXITSTATUS(status));
            write_to_log("Child process %d exited with status %d", pid, WEXITSTATUS(status));
            fprintf(stderr, "Child process %d exited with status %d\n", pid, WEXITSTATUS(status));
        } else if (WIFSIGNALED(status)) {
            write_to_log("Child process %d killed by signal %d", pid, WTERMSIG(status));
            fprintf(stderr, "Child process %d killed by signal %d\n", pid, WTERMSIG(status));
        }
        
        child_exited = 1;
        child_counter += 1;  // Increment by 1 for each child
        
        // Force flush log file
        if (log_fd >= 0) {
            fsync(log_fd);
        }
    }
}

// Signal handlers for daemon process
void handle_sigusr1(int sig) {
    (void)sig; // Suppress unused parameter warning
    write_to_log("Received SIGUSR1 signal");
}

void handle_sighup(int sig) {
    (void)sig; // Suppress unused parameter warning
    write_to_log("Received SIGHUP signal - reconfiguring");
}

void handle_sigterm(int sig) {
    (void)sig; // Suppress unused parameter warning
    write_to_log("Received SIGTERM signal - shutting down");
    
    // Clean up and exit
    clean_up(0);
}

// Function to verify FIFO existence or create if not exists
int ensure_fifo_exists(const char *fifo_path) {
    struct stat st;
    
    // Debug output
    fprintf(stderr, "Checking FIFO: %s\n", fifo_path);
    
    // Check if FIFO exists
    if (stat(fifo_path, &st) == -1) {
        if (errno == ENOENT) {
            // FIFO doesn't exist, create it
            fprintf(stderr, "Creating FIFO: %s\n", fifo_path);
            if (mkfifo(fifo_path, 0666) < 0) {
                char err_msg[256];
                snprintf(err_msg, sizeof(err_msg), "Failed to create FIFO %s", fifo_path);
                SET_ERROR(errno, err_msg);
                return -1;
            }
            fprintf(stderr, "FIFO created successfully: %s\n", fifo_path);
        } else {
            // Other error
            char err_msg[256];
            snprintf(err_msg, sizeof(err_msg), "Failed to check FIFO %s", fifo_path);
            SET_ERROR(errno, err_msg);
            return -1;
        }
    } else if (!S_ISFIFO(st.st_mode)) {
        // Path exists but is not a FIFO
        char err_msg[256];
        snprintf(err_msg, sizeof(err_msg), "Path %s exists but is not a FIFO", fifo_path);
        SET_ERROR(EEXIST, err_msg);
        return -1;
    } else {
        fprintf(stderr, "FIFO already exists: %s\n", fifo_path);
    }
    
    return 0; // FIFO exists or was created
}

// Function to daemonize the process
void daemonize(void) {
    pid_t pid;
    
    fprintf(stderr, "Starting daemonization process...\n");
    
    // First fork
    pid = fork();
    if (pid < 0) {
        SET_ERROR(errno, "First fork failed");
        exit(1);
    }
    
    // Exit parent process
    if (pid > 0) {
        fprintf(stderr, "Parent exiting after first fork, daemon continuing with PID %d\n", pid);
        exit(0);
    }
    
    fprintf(stderr, "First child process continuing (PID: %d)\n", getpid());
    
    // Child becomes session leader
    if (setsid() < 0) {
        SET_ERROR(errno, "setsid failed");
        exit(1);
    }
    
    fprintf(stderr, "Session ID set successfully\n");
    
    // Ignore SIGHUP
    signal(SIGHUP, SIG_IGN);
    
    // Second fork
    pid = fork();
    if (pid < 0) {
        SET_ERROR(errno, "Second fork failed");
        exit(1);
    }
    
    // Exit first child
    if (pid > 0) {
        fprintf(stderr, "First child exiting after second fork, daemon continuing with PID %d\n", pid);
        exit(0);
    }
    
    fprintf(stderr, "Second child process continuing as daemon (PID: %d)\n", getpid());
    
    // Change working directory to root
    fprintf(stderr, "Changing directory to /\n");
    if (chdir("/") < 0) {
        fprintf(stderr, "Failed to change directory: %s\n", strerror(errno));
    }
    
    // Open the log file if not already open
    if (log_fd < 0) {
        log_fd = open(LOG_FILE, O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (log_fd < 0) {
            fprintf(stderr, "Failed to open log file: %s\n", strerror(errno));
            exit(1);
        }
    }
    
    fprintf(stderr, "Log file opened successfully: %s\n", LOG_FILE);
    
    // Write test message to log file
    write(log_fd, "Test message - log file initialized\n", 35);
    fsync(log_fd);
    
    // Close standard file descriptors
    fprintf(stderr, "Closing standard file descriptors\n");
    close(STDIN_FILENO);
    
    // Redirect stdout and stderr to log file
    dup2(log_fd, STDOUT_FILENO);
    dup2(log_fd, STDERR_FILENO);
    
    // Setup signal handlers
    signal(SIGUSR1, handle_sigusr1);
    signal(SIGHUP, handle_sighup);
    signal(SIGTERM, handle_sigterm);
    signal(SIGCHLD, handle_sigchld);
    
    // Log daemon startup
    write_to_log("Daemon started with PID %d", getpid());
}

// First child process function
void child_process_1(int num1, int num2) {
    // Sleep for 10 seconds
    fprintf(stderr, "Child 1 (PID %d): Starting sleep for 10 seconds\n", getpid());
    sleep(10);
    
    // Open the first FIFO for reading
    fprintf(stderr, "Child 1: Opening FIFO1 for reading\n");
    int fifo1 = open(FIFO1, O_RDONLY);
    if (fifo1 < 0) {
        fprintf(stderr, "Child 1: Failed to open FIFO1: %s\n", strerror(errno));
        SET_ERROR(errno, "Child 1: Failed to open FIFO1 for reading");
        exit(1);
    }
    
    // Read the two integers (we already have them from the parent)
    int values[2];
    values[0] = num1;
    values[1] = num2;
    
    fprintf(stderr, "Child 1: Received values: %d and %d\n", values[0], values[1]);
    
    // Close the FIFO
    close(fifo1);
    
    // Determine the larger number
    int larger = (values[0] > values[1]) ? values[0] : values[1];
    fprintf(stderr, "Child 1: Determined larger number is %d\n", larger);
    
    // Open the second FIFO for writing
    fprintf(stderr, "Child 1: Opening FIFO2 for writing\n");
    int fifo2 = open(FIFO2, O_WRONLY);
    if (fifo2 < 0) {
        fprintf(stderr, "Child 1: Failed to open FIFO2: %s\n", strerror(errno));
        SET_ERROR(errno, "Child 1: Failed to open FIFO2 for writing");
        exit(1);
    }
    
    // Write the larger number to the second FIFO
    fprintf(stderr, "Child 1: Writing larger number %d to FIFO2\n", larger);
    if (write(fifo2, &larger, sizeof(int)) < 0) {
        fprintf(stderr, "Child 1: Failed to write to FIFO2: %s\n", strerror(errno));
        SET_ERROR(errno, "Child 1: Failed to write to FIFO2");
        close(fifo2);
        exit(1);
    }
    
    // Close the FIFO
    close(fifo2);
    
    fprintf(stderr, "Child process 1 (PID %d): Completed, exiting\n", getpid());
    fprintf(stderr, "[INFO] Child 1: Determined %d is the larger number.\n", larger);
    printf("Child process 1 (PID %d): Determined larger number is %d\n", getpid(), larger);
    exit(0);
}

// Second child process function
void child_process_2(void) {
    // Sleep for 10 seconds
    fprintf(stderr, "Child 2 (PID %d): Starting sleep for 10 seconds\n", getpid());
    sleep(10);
    
    // Verify FIFO2 exists
    fprintf(stderr, "Child 2: Verifying FIFO2 exists\n");
    if (access(FIFO2, F_OK) != 0) {
        fprintf(stderr, "Child 2: FIFO2 does not exist: %s\n", strerror(errno));
        SET_ERROR(errno, "Child 2: FIFO2 does not exist");
        exit(1);
    }
    
    // Open the second FIFO for reading
    fprintf(stderr, "Child 2: Opening FIFO2 for reading\n");
    int fifo2 = open(FIFO2, O_RDONLY);
    if (fifo2 < 0) {
        fprintf(stderr, "Child 2: Failed to open FIFO2: %s\n", strerror(errno));
        SET_ERROR(errno, "Child 2: Failed to open FIFO2 for reading");
        exit(1);
    }
    
    // Read the larger number
    int larger;
    fprintf(stderr, "Child 2: Reading larger number from FIFO2\n");
    if (read(fifo2, &larger, sizeof(int)) < 0) {
        fprintf(stderr, "Child 2: Failed to read from FIFO2: %s\n", strerror(errno));
        SET_ERROR(errno, "Child 2: Failed to read from FIFO2");
        close(fifo2);
        exit(1);
    }
    
    // Close the FIFO
    close(fifo2);
    
    // Print the larger number
    fprintf(stderr, "Child 2: Read larger number: %d\n", larger);
    fprintf(stderr, "[INFO] Child 2: The larger number is: %d\n", larger);
    fprintf(stderr, "Child process 2 (PID %d): Completed, exiting\n", getpid());
    printf("Child process 2 (PID %d): The larger number is %d\n", getpid(), larger);
    exit(0);
}

int main(int argc, char *argv[]) {
    // Check command line arguments
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <number1> <number2>\n", argv[0]);
        return 1;
    }
    
    fprintf(stderr, "Starting program with arguments: %s %s\n", argv[1], argv[2]);
    
    // Parse the two integer arguments
    int num1 = atoi(argv[1]);
    int num2 = atoi(argv[2]);
    
    fprintf(stderr, "Parsed arguments: num1=%d, num2=%d\n", num1, num2);
    
    // Initialize result variable (as required by the assignment)
    int result = 0;
    
    // Open log file
    log_file = fopen(LOG_FILE, "a");
    if (log_file == NULL) {
        fprintf(stderr, "Failed to open log file: %s\n", strerror(errno));
        return 1;
    }
    
    // Create/verify FIFOs
    fprintf(stderr, "Verifying/creating FIFOs\n");
    if (ensure_fifo_exists(FIFO1) < 0) {
        fprintf(stderr, "Failed to create/verify FIFO1: %s\n", global_error_block.error_message);
        fclose(log_file);
        return 1;
    }
    
    if (ensure_fifo_exists(FIFO2) < 0) {
        fprintf(stderr, "Failed to create/verify FIFO2: %s\n", global_error_block.error_message);
        unlink(FIFO1);
        fclose(log_file);
        return 1;
    }
    
    // Set up signal handlers
    fprintf(stderr, "Setting up signal handlers\n");
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handle_sigchld;
    sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
    sigaction(SIGCHLD, &sa, NULL);
    
    // Create child processes first
    fprintf(stderr, "Creating first child process\n");
    pid_t pid1 = fork();
    if (pid1 < 0) {
        fprintf(stderr, "Failed to fork first child: %s\n", strerror(errno));
        SET_ERROR(errno, "Failed to fork first child");
        fprintf(stderr, "Error: %s\n", global_error_block.error_message);
        unlink(FIFO1);
        unlink(FIFO2);
        fclose(log_file);
        return 1;
    } else if (pid1 == 0) {
        // First child process
        if (log_file != NULL) {
            fclose(log_file);
            log_file = NULL;
        }
        child_process_1(num1, num2);
    }
    
    fprintf(stderr, "Parent: Created first child with PID %d\n", pid1);
    
    fprintf(stderr, "Creating second child process\n");
    pid_t pid2 = fork();
    if (pid2 < 0) {
        fprintf(stderr, "Failed to fork second child: %s\n", strerror(errno));
        SET_ERROR(errno, "Failed to fork second child");
        fprintf(stderr, "Error: %s\n", global_error_block.error_message);
        unlink(FIFO1);
        unlink(FIFO2);
        // Kill first child if it was created
        if (pid1 > 0) kill(pid1, SIGTERM);
        fclose(log_file);
        return 1;
    } else if (pid2 == 0) {
        // Second child process
        if (log_file != NULL) {
            fclose(log_file);
            log_file = NULL;
        }
        child_process_2();
    }
    
    fprintf(stderr, "Parent: Created second child with PID %d\n", pid2);
    
    // Give child processes a moment to start
    fprintf(stderr, "Parent: Sleeping briefly to allow children to start\n");
    usleep(100000);  // Sleep for 100ms
    
    // Convert parent process to daemon
    daemonize();
    
    // Parent process (daemon) loop
    write_to_log("Daemon process started with PID %d", getpid());
    write_to_log("Processing numbers: %d and %d", num1, num2);
    write_to_log("Created child 1 with PID %d", pid1);
    write_to_log("Created child 2 with PID %d", pid2);
    
    // Now open the first FIFO for writing
    int fifo1 = open(FIFO1, O_WRONLY);
    if (fifo1 < 0) {
        write_to_log("Failed to open FIFO1 for writing: %s", strerror(errno));
        SET_ERROR(errno, "Failed to open FIFO1 for writing");
        clean_up(1);
    }
    
    // Write the two integers to the first FIFO
    int values[2] = {num1, num2};
    if (write(fifo1, values, sizeof(values)) < 0) {
        write_to_log("Failed to write to FIFO1: %s", strerror(errno));
        SET_ERROR(errno, "Failed to write to FIFO1");
        close(fifo1);
        clean_up(1);
    }
    
    // Close the FIFO
    close(fifo1);
    write_to_log("Numbers %d and %d written to FIFO1", num1, num2);
    
    // Write command to FIFO2 (just for log consistency)
    write_to_log("Command 'find_larger' sent to FIFO2");
    
    write_to_log("Parent entering main loop...");
    
    int counter = 0;
    time_t start_time = time(NULL); // Initialize start time
    
    // Parent process (daemon) loop - continue for at least 15 seconds
    while (child_counter < total_children && (time(NULL) - start_time) < 15) {
        write_to_log("proceeding... (counter: %d, child_counter: %d)", counter++, child_counter);
        
        // Check for child process timeout (> 20 seconds)
        time_t now = time(NULL);
        
        if (now - start_time > 20) {
            write_to_log("Timeout detected - terminating child processes");
            
            // Send SIGTERM to child processes
            if (pid1 > 0) kill(pid1, SIGTERM);
            if (pid2 > 0) kill(pid2, SIGTERM);
            
            break;
        }
        
        // Force flush log file
        if (log_fd >= 0) {
            fsync(log_fd);
        }
        
        sleep(2); // Print message every 2 seconds
    }
    
    // Make sure we capture all child exits
    sleep(2);
    
    write_to_log("Final child_counter value: %d", child_counter);
    write_to_log("All children have exited. Parent is shutting down.");
    
    // Use the result variable as required by the assignment
    result = child_counter;
    
    // Clean up and exit
    clean_up(result);
    
    return result; // This line will never be reached
} 
