import '../../domain/entities/offer.dart';
import '../../domain/repositories/offer_repository.dart';
import '../datasources/catalog_remote_datasource.dart';

class OfferRepositoryImpl implements OfferRepository {
  final CatalogRemoteDataSource remoteDataSource;

  const OfferRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<Offer>> getActiveOffers() {
    return remoteDataSource.getActiveOffers();
  }
}
