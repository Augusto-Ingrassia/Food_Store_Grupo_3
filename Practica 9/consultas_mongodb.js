// Consigna 2 / Paso 1.4: Migración de 5 pedidos reales desde PostgreSQL a MongoDB
// Vacía la colección antes de insertar para poder re-ejecutar el script completo (Parte 2).
db.pedidos.drop();
db.pedidos.insertMany([
  {
    "_id": 1,
    "fecha": "2026-06-13",
    "estado": "TERMINADO",
    "total": 0.0,
    "forma_pago": "TRANSFERENCIA",
    "cliente": {
      "usuario_id": 10130,
      "nombre": "Nombre_10130",
      "apellido": "Apellido_10130",
      "mail": "usuario_10130@foodstore.com",
      "celular": "5491158917253"
    },
    "detalles": [
      {
        "detalle_id": 1,
        "cantidad": 2,
        "precio_unitario": 993.26,
        "subtotal": 1986.52,
        "producto": {
          "producto_id": 43068,
          "nombre": "Producto Masivo 43068",
          "categoria": {
            "categoria_id": 4,
            "nombre": "Pizzas y Empanadas"
          }
        }
      },
      {
        "detalle_id": 200001,
        "cantidad": 2,
        "precio_unitario": 7500.0,
        "subtotal": 15000.0,
        "producto": {
          "producto_id": 1,
          "nombre": "Producto Masivo 1",
          "categoria": {
            "categoria_id": 2,
            "nombre": "Bebidas"
          }
        }
      }
    ]
  },
  {
    "_id": 2,
    "fecha": "2026-08-14",
    "estado": "TERMINADO",
    "total": 0.0,
    "forma_pago": "TARJETA",
    "cliente": {
      "usuario_id": 7636,
      "nombre": "Nombre_7636",
      "apellido": "Apellido_7636",
      "mail": "usuario_7636@foodstore.com",
      "celular": "5491196349901"
    },
    "detalles": [
      {
        "detalle_id": 2,
        "cantidad": 2,
        "precio_unitario": 993.26,
        "subtotal": 1986.52,
        "producto": {
          "producto_id": 38264,
          "nombre": "Producto Masivo 38264",
          "categoria": {
            "categoria_id": 5,
            "nombre": "Ensaladas"
          }
        }
      },
      {
        "detalle_id": 200002,
        "cantidad": 2,
        "precio_unitario": 7500.0,
        "subtotal": 15000.0,
        "producto": {
          "producto_id": 1,
          "nombre": "Producto Masivo 1",
          "categoria": {
            "categoria_id": 2,
            "nombre": "Bebidas"
          }
        }
      }
    ]
  },
  {
    "_id": 3,
    "fecha": "2026-04-03",
    "estado": "CANCELADO",
    "total": 0.0,
    "forma_pago": "TARJETA",
    "cliente": {
      "usuario_id": 16226,
      "nombre": "Nombre_16226",
      "apellido": "Apellido_16226",
      "mail": "usuario_16226@foodstore.com",
      "celular": "5491173853782"
    },
    "detalles": [
      {
        "detalle_id": 3,
        "cantidad": 2,
        "precio_unitario": 993.26,
        "subtotal": 1986.52,
        "producto": {
          "producto_id": 49690,
          "nombre": "Producto Masivo 49690",
          "categoria": {
            "categoria_id": 1,
            "nombre": "Comida Rápida"
          }
        }
      },
      {
        "detalle_id": 200003,
        "cantidad": 2,
        "precio_unitario": 7500.0,
        "subtotal": 15000.0,
        "producto": {
          "producto_id": 1,
          "nombre": "Producto Masivo 1",
          "categoria": {
            "categoria_id": 2,
            "nombre": "Bebidas"
          }
        }
      }
    ]
  },
  {
    "_id": 4,
    "fecha": "2026-03-10",
    "estado": "PENDIENTE",
    "total": 0.0,
    "forma_pago": "EFECTIVO",
    "cliente": {
      "usuario_id": 5366,
      "nombre": "Nombre_5366",
      "apellido": "Apellido_5366",
      "mail": "usuario_5366@foodstore.com",
      "celular": "5491161547980"
    },
    "detalles": [
      {
        "detalle_id": 4,
        "cantidad": 2,
        "precio_unitario": 993.26,
        "subtotal": 1986.52,
        "producto": {
          "producto_id": 7470,
          "nombre": "Producto Masivo 7470",
          "categoria": {
            "categoria_id": 1,
            "nombre": "Comida Rápida"
          }
        }
      },
      {
        "detalle_id": 200004,
        "cantidad": 2,
        "precio_unitario": 7500.0,
        "subtotal": 15000.0,
        "producto": {
          "producto_id": 1,
          "nombre": "Producto Masivo 1",
          "categoria": {
            "categoria_id": 2,
            "nombre": "Bebidas"
          }
        }
      }
    ]
  },
  {
    "_id": 5,
    "fecha": "2025-09-25",
    "estado": "CONFIRMADO",
    "total": 0.0,
    "forma_pago": "EFECTIVO",
    "cliente": {
      "usuario_id": 17023,
      "nombre": "Nombre_17023",
      "apellido": "Apellido_17023",
      "mail": "usuario_17023@foodstore.com",
      "celular": "5491165953644"
    },
    "detalles": [
      {
        "detalle_id": 5,
        "cantidad": 2,
        "precio_unitario": 993.26,
        "subtotal": 1986.52,
        "producto": {
          "producto_id": 46542,
          "nombre": "Producto Masivo 46542",
          "categoria": {
            "categoria_id": 3,
            "nombre": "Postres"
          }
        }
      },
      {
        "detalle_id": 200005,
        "cantidad": 2,
        "precio_unitario": 7500.0,
        "subtotal": 15000.0,
        "producto": {
          "producto_id": 1,
          "nombre": "Producto Masivo 1",
          "categoria": {
            "categoria_id": 2,
            "nombre": "Bebidas"
          }
        }
      }
    ]
  }
]);

// =============================================================================
// Parte 2 · Consultas y verificación (Consigna 4)
// Ejecución: mongosh "mongodb://localhost:27017/food_store" --quiet --file consultas_mongodb.js
// =============================================================================

// a) Todos los pedidos con su identificador y estado
print("a) Todos los pedidos (_id, estado)");
printjson(db.pedidos.find({}, { _id: 1, estado: 1 }).sort({ _id: 1 }).toArray());

// b) Pedidos en un estado existente en los datos migrados: TERMINADO
print("b) Pedidos con estado TERMINADO");
printjson(db.pedidos.find({ estado: "TERMINADO" }, { _id: 1, estado: 1 }).sort({ _id: 1 }).toArray());
print("   cantidad: " + db.pedidos.countDocuments({ estado: "TERMINADO" }));

// c) Pedidos que contienen un producto determinado dentro del arreglo de líneas
//    (notación de punto sobre el arreglo embebido "detalles")
print("c) Pedidos que contienen el producto_id 43068");
printjson(db.pedidos.find({ "detalles.producto.producto_id": 43068 }, { _id: 1 }).sort({ _id: 1 }).toArray());
print("   cantidad: " + db.pedidos.countDocuments({ "detalles.producto.producto_id": 43068 }));

// c') Mismo criterio con el producto presente en todos los pedidos (producto_id 1)
print("c') Pedidos que contienen el producto_id 1");
printjson(db.pedidos.find({ "detalles.producto.producto_id": 1 }, { _id: 1 }).sort({ _id: 1 }).toArray());
print("   cantidad: " + db.pedidos.countDocuments({ "detalles.producto.producto_id": 1 }));

// d) Pedidos con total superior a 15000.
//    Umbral: mismo criterio de "ventas de alto valor" usado por el equipo en la
//    Práctica 5 (subtotal > 15000). Ninguna línea individual lo supera (la
//    mayor es exactamente 15000), así que solo lo superan pedidos cuyo total
//    combina varias líneas.
print("d) Pedidos con total > 15000 (campo total almacenado)");
printjson(db.pedidos.find({ total: { $gt: 15000 } }, { _id: 1, total: 1 }).sort({ _id: 1 }).toArray());

// d corregida) El campo total migró en 0 y no coincide con la suma de las
//    líneas (en PostgreSQL trg_total_ins lo mantiene = SUM(subtotal)).
//    Se corrige la consulta: el total se calcula desde el arreglo embebido.
print("d corregida) Pedidos con SUM(detalles.subtotal) > 15000");
printjson(db.pedidos.find(
  { $expr: { $gt: [{ $sum: "$detalles.subtotal" }, 15000] } },
  { _id: 1, total: 1, total_calculado: { $round: [{ $sum: "$detalles.subtotal" }, 2] } }
).sort({ _id: 1 }).toArray());
