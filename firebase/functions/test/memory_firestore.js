"use strict";

function createMemoryAdmin(initial = {}) {
  const documents = new Map(
      Object.entries(initial).map(([key, value]) => [key, {...value}]),
  );
  let autoId = 0;
  let transactionTail = Promise.resolve();

  const sentinel = (operation, values = []) => ({
    __memoryFirestoreOperation: operation,
    values,
  });
  const FieldValue = {
    arrayUnion: (...values) => sentinel("arrayUnion", values),
    increment: (value) => sentinel("increment", [value]),
    serverTimestamp: () => sentinel("serverTimestamp"),
  };
  const Timestamp = {
    fromMillis: (millis) => ({millis, toMillis: () => millis}),
    now: () => {
      const millis = Date.now();
      return {millis, toMillis: () => millis};
    },
  };

  function applyValue(previous, value) {
    if (!value || typeof value !== "object" ||
        !value.__memoryFirestoreOperation) return value;
    if (value.__memoryFirestoreOperation === "arrayUnion") {
      return [...new Set([
        ...(Array.isArray(previous) ? previous : []),
        ...value.values,
      ])];
    }
    if (value.__memoryFirestoreOperation === "increment") {
      return Number(previous || 0) + Number(value.values[0] || 0);
    }
    if (value.__memoryFirestoreOperation === "serverTimestamp") {
      return {millis: Date.now(), toMillis: () => Date.now()};
    }
    return value;
  }

  function applySet(path, value, merge) {
    const previous = documents.get(path) || {};
    const next = merge ? {...previous} : {};
    for (const [field, fieldValue] of Object.entries(value || {})) {
      next[field] = applyValue(previous[field], fieldValue);
    }
    documents.set(path, next);
  }

  function snapshot(ref) {
    const value = documents.get(ref.path);
    return {
      id: ref.id,
      ref,
      exists: value !== undefined,
      data: () => value,
    };
  }

  class MemoryDocumentReference {
    constructor(path) {
      this.path = path;
      this.id = path.split("/").at(-1);
    }

    collection(name) {
      return new MemoryCollectionReference(`${this.path}/${name}`);
    }

    async get() {
      return snapshot(this);
    }

    async set(value, options = {}) {
      applySet(this.path, value, options.merge === true);
    }

    async update(value) {
      if (!documents.has(this.path)) throw new Error("document-not-found");
      applySet(this.path, value, true);
    }

    async create(value) {
      if (documents.has(this.path)) throw new Error("document-already-exists");
      applySet(this.path, value, false);
    }
  }

  class MemoryQuery {
    constructor(path, filters = [], limitValue = Number.POSITIVE_INFINITY) {
      this.path = path;
      this.filters = filters;
      this.limitValue = limitValue;
    }

    where(field, operator, value) {
      return new MemoryQuery(
          this.path,
          [...this.filters, {field, operator, value}],
          this.limitValue,
      );
    }

    limit(value) {
      return new MemoryQuery(this.path, this.filters, value);
    }

    async get() {
      const prefix = `${this.path}/`;
      const expectedSegments = this.path.split("/").length + 1;
      const docs = [];
      for (const [path, value] of documents.entries()) {
        if (!path.startsWith(prefix) ||
            path.split("/").length !== expectedSegments) continue;
        const matches = this.filters.every((filter) => {
          if (filter.operator !== "==") {
            throw new Error(`unsupported-query-operator:${filter.operator}`);
          }
          return value[filter.field] === filter.value;
        });
        if (!matches) continue;
        docs.push(snapshot(new MemoryDocumentReference(path)));
        if (docs.length >= this.limitValue) break;
      }
      return {docs, empty: docs.length === 0, size: docs.length};
    }
  }

  class MemoryCollectionReference extends MemoryQuery {
    doc(id) {
      const documentId = id || `auto_${++autoId}`;
      return new MemoryDocumentReference(`${this.path}/${documentId}`);
    }
  }

  const db = {
    collection(name) {
      return new MemoryCollectionReference(name);
    },

    async runTransaction(callback) {
      let release;
      const previous = transactionTail;
      transactionTail = new Promise((resolve) => {
        release = resolve;
      });
      await previous;
      const writes = [];
      try {
        const result = await callback({
          get: async (target) => target instanceof MemoryQuery ?
            target.get() : snapshot(target),
          set: (ref, value, options = {}) => writes.push({
            operation: "set",
            ref,
            value,
            merge: options.merge === true,
          }),
          update: (ref, value) => writes.push({
            operation: "update",
            ref,
            value,
            merge: true,
          }),
          create: (ref, value) => writes.push({
            operation: "create",
            ref,
            value,
            merge: false,
          }),
        });
        for (const write of writes) {
          if (write.operation === "create" && documents.has(write.ref.path)) {
            throw new Error("document-already-exists");
          }
          if (write.operation === "update" && !documents.has(write.ref.path)) {
            throw new Error("document-not-found");
          }
          applySet(write.ref.path, write.value, write.merge);
        }
        return result;
      } finally {
        release();
      }
    },
  };

  function firestore() {
    return db;
  }
  firestore.FieldValue = FieldValue;
  firestore.Timestamp = Timestamp;

  return {
    admin: {firestore},
    db,
    documents,
    read: (path) => documents.get(path),
  };
}

module.exports = {createMemoryAdmin};
