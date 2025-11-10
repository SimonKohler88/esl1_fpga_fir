import sys
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout,
    QHBoxLayout, QPushButton, QLabel, QTextEdit, QLineEdit
)
from PyQt5.QtCore import Qt, QProcess, QTimer
from PyQt5.QtGui import QFont
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.backends.backend_qt5agg import NavigationToolbar2QT as NavigationToolbar
from matplotlib.figure import Figure
import numpy as np

"""
Commands:
  S<addr>$<value> - Set register (addr: 0-64, value: signed 16-bit)
  R<addr>         - Read register (addr: 0-64)
  T<interval>     - Set timer interval in ms (100-5000)

Commands must be sent with enter
"""


class BasicQtApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.process = None
        self.read_values = []  # Store read values
        self.current_address = 0  # Track current address being read
        self.waiting_for_response = False  # Flag to track if waiting for response
        self.reading_mode = False  # Flag to indicate we're in reading mode
        self.init_ui()

    def init_ui(self):
        """Initialize the user interface"""
        self.setWindowTitle("Basic PyQt6 Application")
        self.setGeometry(100, 100, 800, 600)

        # Create central widget and main layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # Matplotlib canvas
        self.figure = Figure(figsize=(8, 4))
        self.canvas = FigureCanvas(self.figure)
        self.toolbar = NavigationToolbar(self.canvas, self)

        main_layout.addWidget(self.toolbar)
        main_layout.addWidget(self.canvas)

        # Bottom section with buttons and console
        bottom_layout = QHBoxLayout()

        # Left side: Buttons
        button_layout = QVBoxLayout()

        connect_btn = QPushButton("Connect")
        connect_btn.clicked.connect(self.on_connect_clicked)
        button_layout.addWidget(connect_btn)

        disconnect_btn = QPushButton("Disconnect")
        disconnect_btn.clicked.connect(self.on_disconnect_clicked)
        button_layout.addWidget(disconnect_btn)

        write_btn = QPushButton("Write")
        write_btn.clicked.connect(self.on_write_clicked)
        button_layout.addWidget(write_btn)

        read_btn = QPushButton("Read")
        read_btn.clicked.connect(self.on_read_clicked)
        button_layout.addWidget(read_btn)

        button_layout.addStretch()

        # Right side: Command input and Console
        console_layout = QVBoxLayout()

        # Command input
        self.command_input = QLineEdit()
        self.command_input.setPlaceholderText("Enter command and press Enter...")
        self.command_input.returnPressed.connect(self.send_command)
        console_layout.addWidget(self.command_input)

        # Console
        self.console = QTextEdit()
        self.console.setReadOnly(True)
        self.console.setPlaceholderText("Console output...")
        console_layout.addWidget(self.console)

        # Add to bottom layout
        bottom_layout.addLayout(button_layout, 1)
        bottom_layout.addLayout(console_layout, 3)

        main_layout.addLayout(bottom_layout)

        # Top level buttons
        top_button_layout = QHBoxLayout()

        plot_btn = QPushButton("Plot Example")
        plot_btn.clicked.connect(self.plot_example)
        top_button_layout.addWidget(plot_btn)

        exit_btn = QPushButton("Exit")
        exit_btn.clicked.connect(self.close)
        top_button_layout.addWidget(exit_btn)

        main_layout.addLayout(top_button_layout)

    def log_to_console(self, message):
        """Helper method to log messages to console"""
        self.console.append(message)

    def send_command(self):
        """Send command from input field to the process"""
        command = self.command_input.text()
        if command and self.process and self.process.state() == QProcess.Running:
            self.log_to_console(f"> {command}")
            self.process.write(f"{command}\n".encode())
            self.command_input.clear()
        elif not self.process or self.process.state() != QProcess.Running:
            self.log_to_console("Error: Process not running. Please connect first.")

    def on_connect_clicked(self):
        """Handle connect button click"""
        self.log_to_console("Connecting to Nios II Command Shell...")

        # Path to Nios II Command Shell
        nios2_path = r"C:\intelFPGA_lite\18.1\nios2eds"
        shell_script = r"C:\intelFPGA_lite\18.1\nios2eds\Nios II Command Shell.bat"

        # Create QProcess
        self.process = QProcess(self)
        self.process.setWorkingDirectory(nios2_path)

        # Connect signals to handle output
        self.process.readyReadStandardOutput.connect(self.handle_stdout)
        self.process.readyReadStandardError.connect(self.handle_stderr)
        self.process.finished.connect(self.process_finished)

        # Start the process
        self.process.start("cmd.exe", ["/K", shell_script])

    def on_disconnect_clicked(self):
        """Handle disconnect button click"""
        if self.process and self.process.state() == QProcess.Running:
            self.log_to_console("Disconnecting from Nios II Command Shell...")

            # Send Ctrl-C to the process
            self.log_to_console("Sending Ctrl-C to process...")
            self.process.write(b'\x03')  # Ctrl-C is ASCII code 3

            # Wait a moment for the process to handle Ctrl-C
            QTimer.singleShot(500, self.terminate_process)
        else:
            self.log_to_console("No active connection to disconnect")

    def terminate_process(self):
        """Terminate the process after sending Ctrl-C"""
        if self.process and self.process.state() == QProcess.Running:
            self.process.terminate()
            # Give it a moment to terminate gracefully
            if not self.process.waitForFinished(3000):
                # If it doesn't finish within 3 seconds, force kill
                self.process.kill()
                self.log_to_console("Process forcefully terminated")
            else:
                self.log_to_console("Process terminated gracefully")

    def handle_stderr(self):
        """Handle standard error from the process"""
        if self.process:
            data = self.process.readAllStandardError()
            text = bytes(data).decode("utf-8", errors="ignore")
            self.console.append(f"Error: {text}")

    def process_finished(self):
        """Handle process termination"""
        self.log_to_console("\n--- Process finished ---")

    def on_write_clicked(self):
        """Handle write button click"""
        self.log_to_console("Write button clicked")

    def on_read_clicked(self):
        """Handle read button click"""
        self.log_to_console("Reading from all 64 addresses...")

        if not self.process or self.process.state() != QProcess.Running:
            self.log_to_console("Error: Process not running. Please connect first.")
            return

        # Clear previous values and start reading
        self.read_values = []
        self.current_address = 0
        self.reading_mode = True

        # Send first read command
        self.send_read_command()

    def send_read_command(self):
        """Send read command for current address"""
        if self.current_address < 64:
            command = f"R{self.current_address}"
            for each in command:
                self.process.write(f"{each}".encode(encoding='ascii'))
            self.process.write(f"\n".encode(encoding='ascii'))
            self.log_to_console(f"> {command}")
            self.waiting_for_response = True
        else:
            # All addresses read, plot the results
            self.reading_mode = False
            self.log_to_console("All addresses read successfully")
            self.plot_read_values()

    def handle_stdout(self):
        """Handle standard output from the process"""
        if self.process:
            data = self.process.readAllStandardOutput()
            text = bytes(data).decode("utf-8", errors="ignore")
            self.console.append(text)

            # Parse read responses if in reading mode
            if self.reading_mode and self.waiting_for_response:
                self.parse_read_response(text)

    def parse_read_response(self, text):
        """Parse response from read commands"""
        # Response format: "Read reg[addr] = value"
        lines = text.strip().split('\n')
        for line in lines:
            # Look for pattern: Read reg[number] = number
            import re
            match = re.search(r'Read reg\[(\d+)\]\s*=\s*(-?\d+)', line)
            if match:
                addr = int(match.group(1))
                value = int(match.group(2))

                # Verify it's the address we expected
                if addr == self.current_address:
                    self.read_values.append(value)
                    self.log_to_console(f"Address {addr}: {value}")

                    # Move to next address
                    self.current_address += 1
                    self.waiting_for_response = False

                    # Send next command after brief delay (10ms)
                    QTimer.singleShot(10, self.send_read_command)
                else:
                    self.log_to_console(f"Warning: Received address {addr}, expected {self.current_address}")

    def plot_read_values(self):
        """Plot the values read from all 64 addresses"""
        self.figure.clear()
        ax = self.figure.add_subplot(111)

        # Create address array (0-63)
        addresses = np.arange(64)
        values = np.array(self.read_values[:64])

        # Plot the data
        ax.plot(addresses, values, 'b-', marker='o', markersize=4, linewidth=1.5)
        ax.set_xlabel('Address')
        ax.set_ylabel('Value')
        ax.set_title('Register Values (Addresses 0-63)')
        ax.grid(True, alpha=0.3)

        # Optionally add value labels on hover or at specific points
        ax.set_xlim(-1, 64)

        # Refresh canvas
        self.canvas.draw()

        self.log_to_console(f"Plot updated with {len(values)} values")
        self.log_to_console(f"Min: {np.min(values)}, Max: {np.max(values)}, Mean: {np.mean(values):.2f}")

    def plot_example(self):
        """Plot an example graph"""
        self.figure.clear()

        # Create a subplot
        ax = self.figure.add_subplot(111)

        # Generate sample data
        t = np.linspace(0, 2 * np.pi, 1000)
        y1 = np.sin(2 * np.pi * 5 * t)
        y2 = np.cos(2 * np.pi * 3 * t)

        # Plot the data
        ax.plot(t, y1, label='sin(10πt)')
        ax.plot(t, y2, label='cos(6πt)')
        ax.set_xlabel('Time (s)')
        ax.set_ylabel('Amplitude')
        ax.set_title('Example Plot')
        ax.legend()
        ax.grid(True)

        # Refresh canvas
        self.canvas.draw()

        self.log_to_console("Plot updated")


def main():
    app = QApplication(sys.argv)
    window = BasicQtApp()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
