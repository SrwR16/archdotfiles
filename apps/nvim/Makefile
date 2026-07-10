# Variables
CONFIG_DIR = $(HOME)/.config/nvim

.PHONY: install uninstall

install:
	@echo "Installing Dotfiles nvim configuration..."
	mkdir -p $(CONFIG_DIR)
	
	# Install libraries (read-only)
	install -m 777 nvim/* $(CONFIG_DIR)/
	@echo "Done!"

uninstall:
	rm -rf $(CONFIG_DIR)
	@echo "Removed Dotfiles nvim configuration."
