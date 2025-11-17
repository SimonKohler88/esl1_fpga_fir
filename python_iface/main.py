import sys
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout,
    QHBoxLayout, QPushButton, QLabel, QTextEdit, QLineEdit, QComboBox
)
from PyQt5.QtCore import Qt, QTimer, QThread, pyqtSignal
from PyQt5.QtGui import QFont
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.backends.backend_qt5agg import NavigationToolbar2QT as NavigationToolbar
from matplotlib.figure import Figure
import numpy as np
import serial
import serial.tools.list_ports
from scipy.signal import firwin, freqz


"""
Commands:
  S<addr>$<value> - Set register (addr: 0-64, value: signed 16-bit)
  R<addr>         - Read register (addr: 0-64)
  T<interval>     - Set timer interval in ms (100-5000)

Commands must be sent with enter
"""


class SerialReaderThread(QThread):
    """Thread for reading from serial port"""
    data_received = pyqtSignal(str)

    def __init__(self, serial_port):
        super().__init__()
        self.serial_port = serial_port
        self.running = True

    def run(self):
        """Continuously read from serial port"""
        while self.running and self.serial_port and self.serial_port.is_open:
            try:
                if self.serial_port.in_waiting > 0:
                    data = self.serial_port.read(self.serial_port.in_waiting)
                    text = data.decode('utf-8', errors='ignore')
                    self.data_received.emit(text)
            except Exception as e:
                self.data_received.emit(f"Error reading: {str(e)}")
                break
            self.msleep(10)  # Small delay to prevent CPU overuse

    def stop(self):
        """Stop the thread"""
        self.running = False


class BasicQtApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.serial_port = None
        self.reader_thread = None
        self.read_values = []  # Store read values
        self.current_address = 0  # Track current address being read
        self.waiting_for_response = False  # Flag to track if waiting for response
        self.reading_mode = False  # Flag to indicate we're in reading mode
        self.response_buffer = ""  # Buffer to accumulate serial data
        self.response_timeout_timer = None  # Timer for response timeout
        self.max_retries = 3  # Maximum retry attempts per address
        self.retry_count = 0  # Current retry count
        self.init_ui()

    def init_ui(self):
        """Initialize the user interface"""
        self.setWindowTitle("Serial UART Communication")
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

        # Left side: Buttons and COM port selection
        button_layout = QVBoxLayout()

        # COM port selection
        port_layout = QHBoxLayout()
        port_label = QLabel("COM Port:")
        self.port_combo = QComboBox()
        self.refresh_ports()
        refresh_port_btn = QPushButton("⟳")
        refresh_port_btn.setMaximumWidth(40)
        refresh_port_btn.clicked.connect(self.refresh_ports)
        port_layout.addWidget(port_label)
        port_layout.addWidget(self.port_combo)
        port_layout.addWidget(refresh_port_btn)
        button_layout.addLayout(port_layout)

        # Baud rate selection
        baud_layout = QHBoxLayout()
        baud_label = QLabel("Baud Rate:")
        self.baud_combo = QComboBox()
        self.baud_combo.addItems(['9600', '19200', '38400', '57600', '115200', '230400', '460800', '921600'])
        self.baud_combo.setCurrentText('115200')
        baud_layout.addWidget(baud_label)
        baud_layout.addWidget(self.baud_combo)
        button_layout.addLayout(baud_layout)

        connect_btn = QPushButton("Connect")
        connect_btn.clicked.connect(self.on_connect_clicked)
        button_layout.addWidget(connect_btn)

        disconnect_btn = QPushButton("Disconnect")
        disconnect_btn.clicked.connect(self.on_disconnect_clicked)
        button_layout.addWidget(disconnect_btn)

        read_btn = QPushButton("Read")
        read_btn.clicked.connect(self.on_read_clicked)
        button_layout.addWidget(read_btn)
        
        compute_btn = QPushButton("Compute and Write")
        compute_btn.clicked.connect(self.on_compute_and_write_clicked)
        button_layout.addWidget(compute_btn)
        
        # Filter design controls
        filter_layout = QHBoxLayout()

        self.cutoff_edit = QLineEdit()
        self.cutoff_edit.setPlaceholderText("Cutoff (e.g. 2000 or 2000,4000)")
        filter_layout.addWidget(self.cutoff_edit)

        self.type_combo = QComboBox()
        self.type_combo.addItems(["lp", "hp", "bp", "bs"])
        filter_layout.addWidget(self.type_combo)

        button_layout.addLayout(filter_layout)

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

    def refresh_ports(self):
        """Refresh available COM ports"""
        self.port_combo.clear()
        ports = serial.tools.list_ports.comports()
        for port in ports:
            self.port_combo.addItem(f"{port.device} - {port.description}", port.device)

        if self.port_combo.count() == 0:
            self.port_combo.addItem("No ports found")

    def log_to_console(self, message):
        """Helper method to log messages to console"""
        self.console.append(message)

    def send_command(self):
        """Send command from input field to the serial port"""
        command = self.command_input.text()
        if command and self.serial_port and self.serial_port.is_open:
            self.log_to_console(f"> {command}")
            try:
                self.serial_port.write(f"{command}\n".encode('utf-8'))
                self.command_input.clear()
            except Exception as e:
                self.log_to_console(f"Error sending command: {str(e)}")
        elif not self.serial_port or not self.serial_port.is_open:
            self.log_to_console("Error: Serial port not open. Please connect first.")

    def on_connect_clicked(self):
        """Handle connect button click"""
        if self.port_combo.count() == 0 or self.port_combo.currentText() == "No ports found":
            self.log_to_console("Error: No COM port selected")
            return

        port_name = self.port_combo.currentData()
        baud_rate = int(self.baud_combo.currentText())

        try:
            self.log_to_console(f"Connecting to {port_name} at {baud_rate} baud...")

            # Open serial port
            self.serial_port = serial.Serial(
                port=port_name,
                baudrate=baud_rate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=1
            )

            # Start reader thread
            self.reader_thread = SerialReaderThread(self.serial_port)
            self.reader_thread.data_received.connect(self.handle_serial_data)
            self.reader_thread.start()

            self.log_to_console(f"Connected successfully to {port_name}")

        except Exception as e:
            self.log_to_console(f"Error connecting: {str(e)}")
            if self.serial_port:
                self.serial_port.close()
                self.serial_port = None

    def on_disconnect_clicked(self):
        """Handle disconnect button click"""
        if self.serial_port and self.serial_port.is_open:
            self.log_to_console("Disconnecting from serial port...")

            # Stop any active reading operations
            self.reading_mode = False
            if self.response_timeout_timer:
                self.response_timeout_timer.stop()
                self.response_timeout_timer = None

            # Stop reader thread
            if self.reader_thread:
                self.reader_thread.stop()
                self.reader_thread.wait()
                self.reader_thread = None

            # Close serial port
            self.serial_port.close()
            self.serial_port = None

            self.log_to_console("Disconnected successfully")
        else:
            self.log_to_console("No active connection to disconnect")

    def handle_serial_data(self, text):
        """Handle data received from serial port"""
        self.console.append(text)

        # Parse read responses if in reading mode
        if self.reading_mode and self.waiting_for_response:
            # Accumulate text in response buffer
            self.response_buffer += text
            self.parse_read_response()

    def on_read_clicked(self):
        """Handle read button click"""
        self.log_to_console("Reading from all 64 addresses...")

        if not self.serial_port or not self.serial_port.is_open:
            self.log_to_console("Error: Serial port not open. Please connect first.")
            return

        # Clear previous values and start reading
        self.read_values = []
        self.current_address = 0
        self.reading_mode = True
        self.response_buffer = ""
        self.retry_count = 0

        # Send first read command
        self.send_read_command()

    def send_read_command(self):
        """Send read command for current address"""
        if self.current_address < 64:
            command = f"R{self.current_address}"
            try:
                # Clear the response buffer before sending command
                self.response_buffer = ""

                self.serial_port.write(f"{command}\n".encode('utf-8'))
                self.log_to_console(f"> {command}")
                self.waiting_for_response = True

                # Start timeout timer (1000ms timeout)
                if self.response_timeout_timer:
                    self.response_timeout_timer.stop()
                self.response_timeout_timer = QTimer()
                self.response_timeout_timer.setSingleShot(True)
                self.response_timeout_timer.timeout.connect(self.handle_response_timeout)
                self.response_timeout_timer.start(1000)

            except Exception as e:
                self.log_to_console(f"Error sending read command: {str(e)}")
                self.reading_mode = False
        else:
            # All addresses read, plot the results
            self.reading_mode = False
            self.log_to_console(f"All 64 addresses read successfully ({len(self.read_values)} values collected)")
            self.plot_read_values()

    def handle_response_timeout(self):
        """Handle timeout when waiting for read response"""
        if self.waiting_for_response and self.reading_mode:
            self.retry_count += 1
            if self.retry_count <= self.max_retries:
                self.log_to_console(f"Timeout waiting for address {self.current_address} (retry {self.retry_count}/{self.max_retries})")
                self.waiting_for_response = False
                # Retry the same command
                QTimer.singleShot(50, self.send_read_command)
            else:
                # Max retries reached, skip this address and continue
                self.log_to_console(f"Error: Max retries reached for address {self.current_address}, skipping...")
                self.read_values.append(0)  # Add placeholder value
                self.current_address += 1
                self.retry_count = 0
                self.waiting_for_response = False
                QTimer.singleShot(50, self.send_read_command)

    def parse_read_response(self):
        """Parse response from read commands using accumulated buffer"""
        # Response format: "Read reg[addr] = value"
        import re

        # Look for pattern in the accumulated buffer
        match = re.search(r'Read reg\[(\d+)\]\s*=\s*(-?\d+)', self.response_buffer)
        if match:
            addr = int(match.group(1))
            value = int(match.group(2))

            # Verify it's the address we expected
            if addr == self.current_address:
                # Stop timeout timer
                if self.response_timeout_timer:
                    self.response_timeout_timer.stop()

                self.read_values.append(value)
                # Don't log each value to avoid console spam
                # self.log_to_console(f"Address {addr}: {value}")

                # Move to next address
                self.current_address += 1
                self.retry_count = 0  # Reset retry count on success
                self.waiting_for_response = False

                # Send next command after brief delay (50ms for better reliability)
                QTimer.singleShot(50, self.send_read_command)
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

    def closeEvent(self, event):
        """Handle window close event"""
        # Stop any active reading operations
        self.reading_mode = False
        if self.response_timeout_timer:
            self.response_timeout_timer.stop()
            self.response_timeout_timer = None

        # Clean up serial connection
        if self.reader_thread:
            self.reader_thread.stop()
            self.reader_thread.wait()

        if self.serial_port and self.serial_port.is_open:
            self.serial_port.close()

        event.accept()
        
    def on_compute_and_write_clicked(self):
        if not self.serial_port or not self.serial_port.is_open:
            self.log_to_console("Error: Serial port not open.")
            return

        # Parse cutoff text
        text = self.cutoff_edit.text().strip()
        if not text:
            self.log_to_console("Error: no cutoff frequency entered.")
            return

        try:
            if "," in text:
                c = [float(x) for x in text.split(",")]
            else:
                c = [float(text)]
        except ValueError:
            self.log_to_console("Error: cutoff must be numeric (e.g. 3000 or 3000,6000).")
            return

        ftype = self.type_combo.currentText()
        fs = 48000.0
        taps = 64
        nyq = fs / 2.0

        # Basic sanity
        if any(f <= 0 or f >= nyq for f in c):
            self.log_to_console(f"Error: cutoff must be in (0, {nyq} Hz).")
            return

        if ftype in ["bp", "bs"] and len(c) != 2:
            self.log_to_console("Error: band-pass/stop requires two cutoff frequencies (f_low,f_high).")
            return

        # ---- FIR design with odd-tap fix for hp / bs ----
        internal_taps = taps
        if ftype in ["hp", "bs"] and (taps % 2 == 0):
            internal_taps = taps + 1  # make it odd for SciPy

        # Normalize cutoffs
        if ftype in ["lp", "hp"]:
            norm = c[0] / nyq
            # keep strictly inside (0,1)
            norm = max(1e-6, min(norm, 0.999999))
            coeff = firwin(internal_taps, norm, pass_zero=(ftype == "lp"))

        else:  # bp / bs
            norm = [f / nyq for f in c]
            norm = [max(1e-6, min(v, 0.999999)) for v in norm]
            coeff = firwin(internal_taps, norm, pass_zero=(ftype == "bs"))

        # Trim back to 64 taps if we increased it
        if internal_taps != taps:
            center = internal_taps // 2
            coeff = np.delete(coeff, center)

        # Scale to Q1.15
        scale = 2**15
        fixed = np.round(coeff * scale)
        fixed = np.clip(fixed, -32768, 32767).astype(np.int16)

        self.log_to_console("Writing computed FIR coefficients...")

        for addr, val in enumerate(fixed):
            cmd = f"S{addr}${int(val)}"
            try:
                self.serial_port.write((cmd + "\n").encode())
                self.log_to_console(f"> {cmd}")
            except Exception as e:
                self.log_to_console(f"Error sending {cmd}: {e}")
                break

        self.log_to_console("Done writing coefficients.")

        
        
        




def main():
    app = QApplication(sys.argv)
    window = BasicQtApp()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
