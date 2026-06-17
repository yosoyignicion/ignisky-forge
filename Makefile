# ignisky-forge Makefile
# La forja de tus perfiles Hermes 🔥

SCRIPT_NAME := ignisky-forge.sh
INSTALL_DIR ?= /usr/local/bin
BATS ?= bats

.PHONY: help install uninstall demo audit clean lint

help:
	@echo "ignisky-forge Makefile 🔥"
	@echo ""
	@echo "  install   - Instala el script en $(INSTALL_DIR)/$(SCRIPT_NAME)"
	@echo "  uninstall - Elimina el script de $(INSTALL_DIR)"
	@echo "  demo      - Ejecuta el script en modo interactivo"
	@echo "  audit     - Verifica el script con shellcheck"
	@echo "  clean     - Limpia archivos temporales"
	@echo "  lint      - Análisis estático con shellcheck"

install:
	@echo "Instalando ignisky-forge..."
	cp $(SCRIPT_NAME) $(INSTALL_DIR)/$(SCRIPT_NAME)
	chmod +x $(INSTALL_DIR)/$(SCRIPT_NAME)
	@echo "✅ Instalado en $(INSTALL_DIR)/$(SCRIPT_NAME)"

uninstall:
	@echo "Desinstalando ignisky-forge..."
	rm -f $(INSTALL_DIR)/$(SCRIPT_NAME)
	@echo "✅ Eliminado de $(INSTALL_DIR)/$(SCRIPT_NAME)"

demo:
	@echo "Ejecutando ignisky-forge..."
	./$(SCRIPT_NAME)

audit:
	@echo "Auditando ignisky-forge con shellcheck..."
	shellcheck $(SCRIPT_NAME) || echo "⚠️  shellcheck no instalado. Instala con: apt install shellcheck"

clean:
	@echo "Limpiando..."
	rm -f *.log
	rm -rf backups/
	@echo "✅ Limpieza completada"

lint:
	@echo "Analizando con shellcheck..."
	shellcheck -x $(SCRIPT_NAME)
