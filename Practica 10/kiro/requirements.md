# Requisitos del Semáforo de Sincronización

*   **REQ-01:** WHEN el `precio_centavos_visto` del ítem en el borrador es distinto al `precio_centavos` actual en el servidor THE SYSTEM SHALL marcar la solicitud como `CONFLICTO`. 
    *Se prueba con: C2*
*   **REQ-02:** WHEN la cantidad solicitada de un producto supera el `stock_visto` disponible en el servidor THE SYSTEM SHALL marcar la solicitud como `RECHAZADO`. 
    *Se prueba con: C3*
*   **REQ-03:** WHEN el producto solicitado en el borrador fue eliminado (`eliminado = 1`) o no está disponible (`disponible = 0`) en el servidor THE SYSTEM SHALL marcar la solicitud como `RECHAZADO`. 
    *Se prueba con: C4*
*   **REQ-04:** WHEN el borrador no presenta diferencias de precio, tiene stock suficiente y el producto está disponible THE SYSTEM SHALL marcar la solicitud como `SIMULADO_APROBADO`. 
    *Se prueba con: C5*