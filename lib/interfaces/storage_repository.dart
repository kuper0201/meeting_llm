// 저장소 인터페이스
abstract class IStorageRepository<T> {
  Future<void> save(String key, T data);
  Future<T?> load(String key);
  Future<void> delete(String key);
  Future<List<T>> loadAll();
}